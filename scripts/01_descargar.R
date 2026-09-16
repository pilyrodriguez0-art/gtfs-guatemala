# 01_descargar.R
# Descarga los KML publicados por la Municipalidad de Guatemala.
# Los archivos que produce este script NO se editan a mano.

mapas <- data.frame(
  id_linea = c("L1", "L2", "L6", "L7", "L12", "L13", "L18", "sistema"),
  mid = c(
    "1FtqnCdWA93KLFeP-OUwlIOQMMz4Hlt4",
    "1PBO6JzswSAvHnTIeq_H8x9byg8s4CtY",
    "10g1kggPBBdLXtQe8uktVa7C5MqUgZzI",
    "1OXgeGUJeOdkOHgT2njwDYh6qfDx-oVM",
    "1_8i9Hg4Y-vUg6xIL3IFguG6cW89ZacY",
    "1tYEyBE7-b0VIjCt5kSH4m0VEOhjvHNI",
    "1-OyQubHliUnu5TDN_BykelEkVe5fTio",
    "1-q3uNeSMBn4WiO04-Ou-9dgfsptXkzE"
  ),
  stringsAsFactors = FALSE
)

dir.create("data/raw", recursive = TRUE, showWarnings = FALSE)

for (i in seq_len(nrow(mapas))) {
  url <- paste0(
    "https://www.google.com/maps/d/kml?mid=",
    mapas$mid[i],
    "&forcekml=1"
  )
  destino <- file.path("data/raw", paste0(mapas$id_linea[i], ".kml"))
  
  message("Descargando ", mapas$id_linea[i], " ...")
  tryCatch(
    download.file(url, destino, mode = "wb", quiet = TRUE),
    error = function(e) {
      warning("Falló ", mapas$id_linea[i], ": ", conditionMessage(e))
    }
  )
  
  Sys.sleep(2)
}

writeLines(
  paste("Última descarga:", Sys.time()),
  "data/raw/FECHA_DESCARGA.txt"
)

message("Listo. Archivos en data/raw/")
