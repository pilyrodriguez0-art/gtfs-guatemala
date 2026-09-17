# 01_descargar.R
# Descarga los KML publicados por la Municipalidad de Guatemala.
# Los archivos que produce este script NO se editan a mano.

mapas <- data.frame(
  id_linea = c("L1", "L2", "L6", "L7", "L12", "L13", "L18", "sistema",
               "R5", "R104", "R105", "R801"),
  mid = c(
    "1FtqnCdWA93KLFeP-OUwlIOQMMz4Hlt4",
    "1PBO6JzswSAvHnTIeq_H8x9byg8s4CtY",
    "10g1kggPBBdLXtQe8uktVa7C5MqUgZzI",
    "1OXgeGUJeOdkOHgT2njwDYh6qfDx-oVM",
    "1_8i9Hg4Y-vUg6xIL3IFguG6cW89ZacY",
    "1tYEyBE7-b0VIjCt5kSH4m0VEOhjvHNI",
    "1-OyQubHliUnu5TDN_BykelEkVe5fTio",
    "1-q3uNeSMBn4WiO04-Ou-9dgfsptXkzE",
    "1Ut7wqvzMdvqISaWjpnhms6jjMbu4_wc",
    "1i0rnw4_AQ-sJtQiudMC1NsxjmR0Moq4",
    "1sk-gaA8P3bcodCdP2tRf9uMrnXYTNns",
    "1Lb4SyhD-_PFo5WsHLdPQqo-NEzaZBos"
  ),
  stringsAsFactors = FALSE
)

# Pendientes: Ruta 402 y Ruta 802 (no se localizaron sus páginas oficiales).
# La 802 tiene trazo y paradas dentro de sistema.kml; la 402 no aparece
# en ninguna fuente descargada hasta ahora.

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