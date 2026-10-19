# 03_orden_paradas.R
# Reconstruye el orden de las paradas a lo largo de cada recorrido.
#
# Problema: los KML dan la ubicación de cada parada pero no el orden
# del recorrido. Los PDFs de rutero sí lo traen, pero dos rutas son
# imagen y el Transmetro no tiene ruteros de ese tipo.
#
# Método: cada parada se proyecta sobre el trazo de su recorrido y se
# calcula cuánto hay que avanzar por la línea para llegar a ella.
# Ordenar por esa distancia reconstruye la secuencia.
#
# La unidad de trabajo es la CAPA, no la ruta: una ruta puede tener
# ramales, y cada ramal es un recorrido propio con su propio trazo.
#
# LIMITACIONES CONOCIDAS
# 1. El método da el orden pero no el sentido. Una línea dibujada al
#    revés produce la secuencia invertida. La tabla de referencia de
#    abajo corrige esto comparando con la parada inicial que declara
#    la Muni.
# 2. En recorridos circulares (como la Línea 7, que hace un bucle por
#    el centro histórico) el punto donde arranca la línea dibujada no
#    coincide con el inicio administrativo de la ruta. La secuencia es
#    correcta; solo empieza en otro punto del circuito. Se decidió no
#    corregirlo porque GTFS no lo requiere y el ruteo tampoco.

library(sf)
library(dplyr)

# --- Tabla de referencia ------------------------------------------------
# Patrón de texto que identifica la parada inicial de cada ruta,
# según las descripciones oficiales de la Municipalidad.

inicios <- tibble::tribble(
  ~id_ruta, ~patron_inicio,          ~descripcion_oficial,
  "L1",     "San Sebasti",           "San Sebastián Z1 - Centro Cívico Z1",
  "L2",     "Hip[oó]dromo",          "Hipódromo del Norte Z2 - San Sebastián Z1",
  "L6",     "Proyectos",             "Proyectos Z6 - FEGUA Z1",
  "L7",     "USAC",                  "USAC Periférico Z12 - La Merced Z1",
  "L12",    "Centra Sur",            "Centra Sur - Plaza Barrios Z1",
  "L13",    "Hangares",              "Hangares Z13 - Tipografía Z1",
  "L18",    "Atl[aá]ntida",          "Atlántida Z18 - FEGUA Z1",
  "R5",     "Parque Col[oó]n",       "Parque Colón Z1 - Puente de la Penitenciaría Z4",
  "R104",   "San Antonio",           "Barrio San Antonio Z6 - Cementerio La Villa Z14",
  "R105",   "Jocotenango",           "Parque Jocotenango Z2 - 9a Av. Z7",
  "R305",   "Vista Hermosa",         "Blvr. Vista Hermosa Z15 - Terminal Z9",
  "R402",   "Santa Fe",              "Col. Santa Fe Z13 - Av. Petapa y 9a av. Z12",
  "R801",   "Los Pinos",             "Parque Los Pinos Z7 - Terminal Z9",
  "R802",   "Los Pinos",             "Parque Los Pinos Z7 - 4a Av. Z1"
)

# --- Carga --------------------------------------------------------------

paradas <- st_read("data/processed/paradas.geojson", quiet = TRUE)
trazos  <- st_read("data/processed/trazos.geojson",  quiet = TRUE)

# --- Función de ordenamiento --------------------------------------------
# Trabaja sobre una capa concreta de un archivo concreto.

ordenar_capa <- function(archivo, nombre_capa) {
  
  p <- paradas |> filter(id_linea == archivo, capa == nombre_capa)
  t <- trazos  |> filter(id_linea == archivo, capa == nombre_capa)
  
  if (nrow(p) == 0) return(NULL)
  
  if (nrow(t) == 0) {
    message("  sin trazo: ", nombre_capa)
    return(NULL)
  }
  
  # Unir todos los segmentos de la capa en una sola línea continua.
  # Google My Maps a veces guarda un recorrido partido en tramos.
  geom_t <- suppressWarnings(st_union(st_geometry(t)))
  
  # st_line_merge solo acepta MULTILINESTRING
  if (inherits(geom_t, "sfc_MULTILINESTRING")) {
    geom_t <- suppressWarnings(st_line_merge(geom_t))
  }
  
  # Si aún quedan varias partes, usar la más larga
  partes <- suppressWarnings(st_cast(geom_t, "LINESTRING"))
  if (length(partes) > 1) {
    geom_t <- partes[which.max(as.numeric(st_length(partes)))]
  }
  
  d <- tryCatch(
    suppressWarnings(st_line_project(geom_t, st_geometry(p))),
    error = function(e) {
      message("  error al proyectar: ", nombre_capa)
      NULL
    }
  )
  
  if (is.null(d) || length(d) != nrow(p)) {
    message("  no se pudo ordenar: ", nombre_capa)
    return(NULL)
  }
  
  p$avance <- as.numeric(d)
  p <- p |> arrange(avance)
  
  # Corregir el sentido si la línea está dibujada al revés
  ruta <- p$id_ruta[1]
  patron <- inicios$patron_inicio[inicios$id_ruta == ruta]
  p$sentido_corregido <- FALSE
  
  if (length(patron) == 1 && !is.na(patron)) {
    coincide <- grepl(patron, p$nombre, ignore.case = TRUE)
    if (any(coincide)) {
      pos <- which(coincide)[1]
      if (pos > nrow(p) / 2) {
        p <- p[rev(seq_len(nrow(p))), ]
        p$sentido_corregido <- TRUE
        message("  sentido invertido: ", nombre_capa)
      }
    }
  }
  
  p$secuencia <- seq_len(nrow(p))
  p
}

# --- Recorrer todas las capas con paradas -------------------------------

combinaciones <- paradas |>
  st_drop_geometry() |>
  distinct(id_linea, capa)

resultados <- list()

for (i in seq_len(nrow(combinaciones))) {
  a <- combinaciones$id_linea[i]
  c <- combinaciones$capa[i]
  r <- ordenar_capa(a, c)
  if (!is.null(r)) resultados[[length(resultados) + 1]] <- r
}

ordenadas <- do.call(rbind, resultados) |> st_as_sf()

message("Capas ordenadas: ", length(resultados), " de ", nrow(combinaciones))
message("Paradas con secuencia: ", nrow(ordenadas))

# --- Escribir -----------------------------------------------------------

st_write(ordenadas, "data/processed/paradas_ordenadas.geojson",
         delete_dsn = TRUE, quiet = TRUE)

message("Listo. data/processed/paradas_ordenadas.geojson")