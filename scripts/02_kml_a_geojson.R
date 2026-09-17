# 02_kml_a_geojson.R
# Convierte los KML crudos a GeoJSON, separando paradas (puntos)
# de trazos de ruta (líneas).

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

tipos <- as.character(st_geometry_type(todo))

paradas <- todo[tipos == "POINT", ]
trazos  <- todo[tipos %in% c("LINESTRING", "MULTILINESTRING"), ]

message("Paradas encontradas: ", nrow(paradas))
message("Trazos encontrados:  ", nrow(trazos))

st_write(paradas, "data/processed/paradas.geojson",
         delete_dsn = TRUE, quiet = TRUE)
st_write(trazos, "data/processed/trazos.geojson",
         delete_dsn = TRUE, quiet = TRUE)

message("Listo. Archivos en data/processed/")