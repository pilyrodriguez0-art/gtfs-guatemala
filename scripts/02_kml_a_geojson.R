# 02_kml_a_geojson.R
# Convierte los KML crudos a GeoJSON, separando paradas, trazos de ruta
# y conexiones de transbordo. Normaliza nombres y descarta decoración.

library(sf)
library(dplyr)

dir.create("data/processed", recursive = TRUE, showWarnings = FALSE)

archivos <- list.files("data/raw", pattern = "\\.kml$", full.names = TRUE)

leer_kml <- function(ruta) {
  id_linea <- tools::file_path_sans_ext(basename(ruta))
  capas <- st_layers(ruta)$name
  
  purrr::map_dfr(capas, function(capa) {
    x <- st_read(ruta, layer = capa, quiet = TRUE)
    if (nrow(x) == 0) return(NULL)
    
    tibble::tibble(
      id_linea = id_linea,
      capa     = capa,
      orden    = seq_len(nrow(x)),
      nombre   = if ("Name" %in% names(x)) x$Name else NA_character_,
      geometry = st_geometry(x)
    )
  })
}

todo <- purrr::map_dfr(archivos, leer_kml) |>
  st_as_sf(crs = 4326)

# --- Descartar capas decorativas ----------------------------------------
# Las capas "Flecha" son marcas de sentido de circulación dibujadas
# sobre el recorrido. Son adorno visual, no datos.

es_flecha <- grepl("^Flecha", todo$capa, ignore.case = TRUE)
message("Elementos decorativos descartados: ", sum(es_flecha))
todo <- todo[!es_flecha, ]

# --- Separar las conexiones de transbordo -------------------------------
# Las capas "Cercanía con Transmetro..." marcan dónde una ruta de TuBus
# conecta con el Transmetro, con el tiempo de caminata.

es_cercania <- grepl("^Cercan", todo$capa, ignore.case = TRUE)
cercanias <- todo[es_cercania, ]
todo      <- todo[!es_cercania, ]

# --- Separar por tipo de geometría --------------------------------------

tipos <- as.character(st_geometry_type(todo))

paradas <- todo[tipos == "POINT", ]

# Algunos trazos vienen como POLYGON porque se dibujaron cerrados
# en Google My Maps. st_cast los convierte a línea sin perder vértices.
poligonos <- todo[tipos %in% c("POLYGON", "MULTIPOLYGON"), ]
lineas    <- todo[tipos %in% c("LINESTRING", "MULTILINESTRING"), ]

if (nrow(poligonos) > 0) {
  poligonos <- st_cast(poligonos, "MULTILINESTRING", warn = FALSE)
}
if (nrow(lineas) > 0) {
  lineas <- st_cast(lineas, "MULTILINESTRING", warn = FALSE)
}

trazos <- rbind(poligonos, lineas)

# --- Normalización de nombres -------------------------------------------

limpiar_nombre <- function(x) {
  x <- gsub("[\r\n]+", " ", x)          # saltos de línea rompen el CSV
  x <- gsub("\\s+", " ", x)             # espacios múltiples a uno solo
  x <- trimws(x)                        # espacios al inicio y al final
  x <- gsub("^L[ÍIíi]nea", "Línea", x)  # corrige "LÍnea", "LInea", "linea"
  x <- gsub("^RUTA\\b", "Ruta", x)      # "RUTA 104" -> "Ruta 104"
  x <- gsub("^ruta\\b", "Ruta", x)
  x
}

paradas$nombre   <- limpiar_nombre(paradas$nombre)
trazos$nombre    <- limpiar_nombre(trazos$nombre)
cercanias$nombre <- limpiar_nombre(cercanias$nombre)

# --- Identificador normalizado ------------------------------------------
# El nombre es para leer; el id es para emparejar tablas.

extraer_id <- function(x) {
  n_linea <- sub(".*[Ll]ínea\\s*(\\d+).*", "\\1", x)
  n_ruta  <- sub(".*[Rr]uta\\s*(\\d+).*", "\\1", x)
  
  ifelse(grepl("[Ll]ínea\\s*\\d+", x), paste0("L", n_linea),
         ifelse(grepl("[Rr]uta\\s*\\d+", x),  paste0("R", n_ruta),
                NA_character_))
}

# Si no se puede extraer de la capa, se usa el archivo de origen,
# que ya lleva el identificador (R104.kml -> R104).
con_respaldo <- function(capa, id_linea) {
  id <- extraer_id(capa)
  ifelse(is.na(id) & id_linea != "sistema", id_linea, id)
}

trazos$id_ruta    <- con_respaldo(trazos$capa, trazos$id_linea)
paradas$id_ruta   <- con_respaldo(paradas$capa, paradas$id_linea)
cercanias$id_ruta <- con_respaldo(cercanias$capa, cercanias$id_linea)

# --- Sistema operador ---------------------------------------------------
# Transmetro y TuBus tienen tarifas y horarios distintos.

detectar_sistema <- function(capa) {
  ifelse(grepl("TUBUS|Ruta\\s*\\d+", capa, ignore.case = TRUE), "tubus",
         ifelse(grepl("TRANSMETRO|Línea", capa, ignore.case = TRUE), "transmetro",
                NA_character_))
}

paradas$sistema   <- detectar_sistema(paradas$capa)
trazos$sistema    <- detectar_sistema(trazos$capa)
cercanias$sistema <- detectar_sistema(cercanias$capa)

# --- Escribir -----------------------------------------------------------

message("Paradas encontradas:    ", nrow(paradas))
message("Trazos encontrados:     ", nrow(trazos))
message("Conexiones encontradas: ", nrow(cercanias))

st_write(paradas, "data/processed/paradas.geojson",
         delete_dsn = TRUE, quiet = TRUE)
st_write(trazos, "data/processed/trazos.geojson",
         delete_dsn = TRUE, quiet = TRUE)
st_write(cercanias, "data/processed/conexiones.geojson",
         delete_dsn = TRUE, quiet = TRUE)

message("Listo. Archivos en data/processed/")