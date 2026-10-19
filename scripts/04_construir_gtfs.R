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
# pero no en la capa maestra del sistema.

library(sf)
library(dplyr)
library(readr)

dir.create("output/gtfs", recursive = TRUE, showWarnings = FALSE)

ordenadas <- st_read("data/processed/paradas_ordenadas.geojson", quiet = TRUE)

# --- Elegir fuente por ruta ---------------------------------------------
# Si una ruta tiene mapa individual, se usa ese. Si no, el del sistema.

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
# Quién opera el sistema. Un solo operador: la Muni.

agency <- tibble(
  agency_id       = "muniguate",
  agency_name     = "Municipalidad de Guatemala",
  agency_url      = "https://www.muniguate.com/movilidadurbana/",
  agency_timezone = "America/Guatemala",
  agency_lang     = "es"
)

# --- routes.txt ---------------------------------------------------------
# route_type 3 = autobús, según el estándar GTFS.
#
# Se excluyen las paradas sin id_ruta: son las 108 estaciones de la
# capa maestra del Transmetro, que sirven a varias líneas y no
# constituyen una ruta. Siguen presentes en stops.txt.

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
# Una fila por parada física. Se deduplica por nombre, promediando
# las coordenadas cuando una misma parada aparece en varias fuentes.

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

message("Paradas únicas: ", nrow(stops))

# --- Escribir lo que ya está listo --------------------------------------

write_csv(agency, "output/gtfs/agency.txt")
write_csv(routes, "output/gtfs/routes.txt")
write_csv(stops,  "output/gtfs/stops.txt")

message("Escritos: agency.txt, routes.txt, stops.txt")