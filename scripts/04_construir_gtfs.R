# 04_construir_gtfs.R
# Construye el feed GTFS a partir de las paradas ordenadas.
#
# GTFS (General Transit Feed Specification) es el formato estándar
# mundial para publicar datos de transporte público. Son varios
# archivos CSV que se relacionan entre sí por identificadores.
#
# Fuente primaria: los mapas individuales de cada ruta, que están
# más actualizados que el mapa del sistema. Se comprobó que la
# estación "Bethania - Dir. Colón" existe en el mapa de la Línea 7
# pero no en la capa maestra del sistema, donde la misma parada
# aparece con otro nombre ("Bethania - Dir. La Merced").
#
# SENTIDOS DE CIRCULACIÓN — LIMITACIÓN DOCUMENTADA
# Las fuentes oficiales no permiten separar ida y vuelta de forma
# confiable:
#
# - Transmetro: no hay ruteros. Los nombres marcan dirección ("Dir.
#   La Merced") solo en tres de siete líneas. Tres líneas no tienen
#   ninguna estación duplicada, lo que sugiere recorridos circulares.
#
# - TuBus: los ruteros numeran las paradas, pero esa numeración es
#   GLOBAL del sistema, no por ruta. Los saltos en la secuencia
#   corresponden a paradas compartidas entre rutas, no a cambios de
#   sentido. Ejemplo: la ruta 801 recorre las paradas 063 a 109 sin
#   interrupción; la 802 comparte con ella los tramos 063-068 y
#   105-109, y la parada 128 aparece en la ruta 105 porque es de la
#   802. Lo mismo con la 084 en la ruta 402.
#
# Por eso cada recorrido se modela como un solo viaje. Inventar un
# corte sería peor que no separarlos: produciría tiempos de viaje
# falsos. Los ramales sí son viajes distintos, porque vienen como
# capas separadas en los mapas.

library(sf)
library(dplyr)
library(readr)

dir.create("output/gtfs", recursive = TRUE, showWarnings = FALSE)

ordenadas <- st_read("data/processed/paradas_ordenadas.geojson", quiet = TRUE)

# --- Elegir fuente por ruta ---------------------------------------------

rutas_con_mapa <- ordenadas |>
  st_drop_geometry() |>
  filter(id_linea != "sistema") |>
  distinct(id_ruta) |>
  pull(id_ruta)

base <- ordenadas |>
  filter(
    (id_linea != "sistema") |
      (id_linea == "sistema" & !(id_ruta %in% rutas_con_mapa))
  )

message("Paradas tras elegir fuente: ", nrow(base))

# --- agency.txt ---------------------------------------------------------

agency <- tibble(
  agency_id       = "muniguate",
  agency_name     = "Municipalidad de Guatemala",
  agency_url      = "https://www.muniguate.com/movilidadurbana/",
  agency_timezone = "America/Guatemala",
  agency_lang     = "es"
)

# --- routes.txt ---------------------------------------------------------

descripciones <- tibble::tribble(
  ~id_ruta, ~nombre_largo,
  "L1",     "San Sebastián - Centro Cívico",
  "L2",     "Hipódromo del Norte - San Sebastián",
  "L6",     "Proyectos - FEGUA",
  "L7",     "USAC Periférico - La Merced",
  "L12",    "Centra Sur - Plaza Barrios",
  "L13",    "Hangares - Tipografía",
  "L18",    "Atlántida - FEGUA",
  "R5",     "Parque Colón - Puente de la Penitenciaría",
  "R104",   "Barrio San Antonio - Cementerio La Villa",
  "R105",   "Parque Jocotenango - 9a Avenida zona 7",
  "R305",   "Bulevar Vista Hermosa - Terminal",
  "R402",   "Colonia Santa Fe - Avenida Petapa",
  "R801",   "Parque Los Pinos - Terminal",
  "R802",   "Parque Los Pinos - 4a Avenida zona 1"
)

routes <- base |>
  st_drop_geometry() |>
  filter(!is.na(id_ruta)) |>
  distinct(id_ruta, sistema) |>
  left_join(descripciones, by = "id_ruta") |>
  transmute(
    route_id         = id_ruta,
    agency_id        = "muniguate",
    route_short_name = sub("^[LR]", "", id_ruta),
    route_long_name  = nombre_largo,
    route_type       = 3,
    route_desc       = ifelse(sistema == "transmetro", "Transmetro", "TuBus")
  ) |>
  arrange(route_desc, route_id)

message("Rutas: ", nrow(routes))

# --- stops.txt ----------------------------------------------------------

coords <- st_coordinates(base)

stops <- base |>
  st_drop_geometry() |>
  mutate(stop_lat = coords[, "Y"], stop_lon = coords[, "X"]) |>
  group_by(nombre) |>
  summarise(
    stop_lat = mean(stop_lat),
    stop_lon = mean(stop_lon),
    .groups = "drop"
  ) |>
  mutate(stop_id = paste0("S", sprintf("%04d", row_number()))) |>
  select(stop_id, stop_name = nombre, stop_lat, stop_lon)

# --- calendar.txt -------------------------------------------------------

calendar <- tibble::tribble(
  ~service_id, ~monday, ~tuesday, ~wednesday, ~thursday, ~friday, ~saturday, ~sunday,
  "LV",        1, 1, 1, 1, 1, 0, 0,
  "SAB",       0, 0, 0, 0, 0, 1, 0,
  "DOM",       0, 0, 0, 0, 0, 0, 1
) |>
  mutate(start_date = "20260101", end_date = "20271231")

# --- trips.txt ----------------------------------------------------------

secuencias <- base |>
  st_drop_geometry() |>
  filter(!is.na(id_ruta)) |>
  select(id_ruta, capa, secuencia, nombre) |>
  arrange(id_ruta, capa, secuencia)

viajes_base <- secuencias |> distinct(id_ruta, capa)

trips <- tidyr::crossing(viajes_base, service_id = calendar$service_id) |>
  mutate(
    trip_id = paste(id_ruta, gsub("[^A-Za-z0-9]", "", capa),
                    service_id, sep = "_"),
    direction_id = 0L
  ) |>
  select(route_id = id_ruta, service_id, trip_id, direction_id, capa)

message("Viajes: ", nrow(trips))

# --- stop_times.txt -----------------------------------------------------
# Con frequencies.txt, los tiempos son desplazamientos desde el inicio
# del viaje, no horas del reloj.
#
# Se asumen 2 minutos entre paradas. Es una estimación: la Muni no
# publica tiempos parada a parada, salvo en algunos ruteros de TuBus
# donde aparecen intervalos de 4 a 7 minutos entre tramos largos.

minutos_entre_paradas <- 2

stop_times <- trips |>
  left_join(secuencias, by = c("route_id" = "id_ruta", "capa"),
            relationship = "many-to-many") |>
  left_join(stops, by = c("nombre" = "stop_name")) |>
  arrange(trip_id, secuencia) |>
  group_by(trip_id) |>
  mutate(
    stop_sequence  = row_number(),
    minutos        = (stop_sequence - 1) * minutos_entre_paradas,
    arrival_time   = sprintf("%02d:%02d:00", minutos %/% 60, minutos %% 60),
    departure_time = arrival_time
  ) |>
  ungroup() |>
  select(trip_id, arrival_time, departure_time, stop_id, stop_sequence)

message("Filas en stop_times: ", nrow(stop_times))

# --- Eliminar paradas huérfanas -----------------------------------------
# Una parada que no aparece en ningún viaje suele venir de una
# discrepancia entre las dos fuentes de la Muni: la misma estación
# con dos nombres distintos. Caso detectado: "Bethania - Dir. Colón"
# en el mapa de la Línea 7 y "Bethania - Dir. La Merced" en el mapa
# del sistema. El feed es válido con ellas, pero queda más limpio sin.

antes <- nrow(stops)
stops <- stops |> filter(stop_id %in% stop_times$stop_id)
message("Paradas huérfanas eliminadas: ", antes - nrow(stops))
message("Paradas únicas: ", nrow(stops))

# --- frequencies.txt ----------------------------------------------------

frequencies <- trips |>
  select(trip_id, service_id) |>
  mutate(
    start_time = case_when(
      service_id == "LV"  ~ "05:00:00",
      service_id == "SAB" ~ "05:30:00",
      TRUE                ~ "06:00:00"
    ),
    end_time = case_when(
      service_id == "LV"  ~ "21:00:00",
      service_id == "SAB" ~ "19:00:00",
      TRUE                ~ "18:00:00"
    ),
    headway_secs = 600L
  ) |>
  select(trip_id, start_time, end_time, headway_secs)

# --- Escribir -----------------------------------------------------------

write_csv(agency,      "output/gtfs/agency.txt")
write_csv(routes,      "output/gtfs/routes.txt")
write_csv(stops,       "output/gtfs/stops.txt")
write_csv(calendar,    "output/gtfs/calendar.txt")
write_csv(select(trips, route_id, service_id, trip_id, direction_id),
          "output/gtfs/trips.txt")
write_csv(stop_times,  "output/gtfs/stop_times.txt")
write_csv(frequencies, "output/gtfs/frequencies.txt")

message("GTFS escrito en output/gtfs/")