# 03_orden_paradas.R
# Reconstruye el orden de las paradas a lo largo de cada recorrido.
#
# Los KML dan la ubicación de cada parada pero no el orden del
# recorrido. Se usan tres métodos, según lo que ofrezca la fuente.
#
# MÉTODO 1 — Secuencia del rutero en PDF (el más confiable)
# Cinco rutas de TuBus tienen rutero con texto extraíble. Su tabla
# da el orden real, incluidas las paradas prestadas de otra serie
# (como la #084 de la ruta 801, por la que pasa la 402).
#
# MÉTODO 2 — Tabla manual
# La ruta 5 no tiene números ni rutero legible, pero su mapa oficial
# muestra el circuito con claridad. La secuencia se transcribió a mano
# desde ese mapa.
#
# MÉTODO 3 — Proyección geométrica (respaldo)
# Para el Transmetro y la ruta 104, que no tienen rutero legible.
# Cada parada se proyecta sobre el trazo con st_line_project() y se
# ordena por la distancia recorrida.
#
# LIMITACIONES DEL MÉTODO 3
# 1. Da el orden pero no el sentido. La tabla de inicios corrige esto.
# 2. En recorridos circulares el punto de arranque de la línea dibujada
#    no coincide con el inicio administrativo.
# 3. Las estaciones de doble abordaje (una sola parada que sirve ambos
#    sentidos) quedan mal ubicadas, porque su posición es ambigua.
#    Fue el caso de Arrivillaga y Vivibien en la ruta 5, motivo por el
#    que esa ruta pasó a tabla manual.
#
# NOTA SOBRE LOS NOMBRES
# Algunos nombres del KML terminan en espacio no separable (U+00A0),
# que Google My Maps introduce al copiar texto. trimws() no lo limpia,
# así que hay que convertirlo a espacio normal primero.

library(sf)
library(dplyr)
library(readr)

# --- Limpieza de texto --------------------------------------------------

limpiar_texto <- function(x) {
  x <- gsub("\u00a0", " ", x)   # espacio no separable -> espacio normal
  x <- gsub("\\s+", " ", x)     # espacios múltiples -> uno solo
  trimws(x)
}

# --- Tabla de referencia: parada inicial de cada ruta -------------------

inicios <- tibble::tribble(
  ~id_ruta, ~patron_inicio,          ~descripcion_oficial,
  "L1",     "San Sebasti",           "San Sebastián Z1 - Centro Cívico Z1",
  "L2",     "Hip[oó]dromo",          "Hipódromo del Norte Z2 - San Sebastián Z1",
  "L6",     "Proyectos",             "Proyectos Z6 - FEGUA Z1",
  "L7",     "USAC",                  "USAC Periférico Z12 - La Merced Z1",
  "L12",    "Centra Sur",            "Centra Sur - Plaza Barrios Z1",
  "L13",    "Hangares",              "Hangares Z13 - Tipografía Z1",
  "L18",    "Atl[aá]ntida",          "Atlántida Z18 - FEGUA Z1",
  "R104",   "San Antonio",           "Barrio San Antonio Z6 - Cementerio La Villa Z14"
)

# --- Tabla manual: orden de la ruta 5 -----------------------------------
# Transcrito del mapa oficial (V1-Ruta-5-Tubus). Circuito cerrado:
# baja desde Parque Colón por el oriente hasta Penitenciaría y regresa.
# Arrivillaga y Vivibien son estaciones de doble abordaje: una sola
# parada para ambos sentidos.

orden_r5 <- c(
  "Parque Colon",
  "Matamoros",
  "Cipreses Norte",
  "Jardines de la Asunción Norte",
  "Arrivillaga",
  "Vivibien",
  "Parque Navidad",
  "Mercado La Palmita",
  "La Palmita",
  "Palacio de los Deportes Norte",
  "Puente de la Penitenciaría",
  "Palacio de los Deportes Sur",
  "Jardines de la Asunción Sur",
  "Cipreses Sur"
)

# --- Carga --------------------------------------------------------------

paradas <- st_read("data/processed/paradas.geojson", quiet = TRUE)
trazos  <- st_read("data/processed/trazos.geojson",  quiet = TRUE)
ruteros <- read_csv("data/processed/ruteros_tubus.csv", show_col_types = FALSE)

# Google My Maps guarda una coordenada Z (altura) que estorba
paradas <- st_zm(paradas, drop = TRUE)
trazos  <- st_zm(trazos,  drop = TRUE)

# Limpiar los nombres de entrada
paradas$nombre <- limpiar_texto(paradas$nombre)
trazos$nombre  <- limpiar_texto(trazos$nombre)

# --- Método 1: por secuencia del rutero ---------------------------------

ordenar_por_rutero <- function(p, ruta) {
  
  r <- ruteros |> filter(id_ruta == ruta) |> arrange(orden)
  if (nrow(r) == 0) return(NULL)
  
  p$n_parada <- sub(".*#(\\d{3}).*", "\\1", p$nombre)
  p$pos <- match(p$n_parada, r$n_parada)
  
  if (any(is.na(p$pos))) {
    message("  ", ruta, ": ", sum(is.na(p$pos)),
            " paradas sin correspondencia en el rutero")
  }
  
  p <- p |> arrange(pos)
  p$metodo <- "rutero"
  p
}

# --- Método 2: tabla manual ---------------------------------------------

ordenar_por_tabla <- function(p, tabla) {
  
  limpio <- limpiar_texto(sub("^Estación\\s+", "", p$nombre))
  p$pos <- match(limpio, tabla)
  
  if (any(is.na(p$pos))) {
    message("  ruta 5: sin correspondencia -> ",
            paste(limpio[is.na(p$pos)], collapse = " | "))
  }
  
  p <- p |> arrange(pos)
  p$metodo <- "tabla_manual"
  p
}

# --- Método 3: proyección geométrica ------------------------------------

ordenar_por_geometria <- function(p, t, nombre_capa) {
  
  if (nrow(t) == 0) {
    message("  sin trazo: ", nombre_capa)
    return(NULL)
  }
  
  geom_t <- suppressWarnings(st_union(st_geometry(t)))
  
  if (inherits(geom_t, "sfc_MULTILINESTRING")) {
    geom_t <- suppressWarnings(st_line_merge(geom_t))
  }
  
  partes <- suppressWarnings(st_cast(geom_t, "LINESTRING"))
  if (length(partes) > 1) {
    geom_t <- partes[which.max(as.numeric(st_length(partes)))]
  }
  
  d <- tryCatch(
    suppressWarnings(st_line_project(geom_t, st_geometry(p))),
    error = function(e) NULL
  )
  
  if (is.null(d) || length(d) != nrow(p)) {
    message("  no se pudo ordenar: ", nombre_capa)
    return(NULL)
  }
  
  p$avance <- as.numeric(d)
  p <- p |> arrange(avance)
  
  ruta <- p$id_ruta[1]
  patron <- inicios$patron_inicio[inicios$id_ruta == ruta]
  
  if (length(patron) == 1 && !is.na(patron)) {
    coincide <- grepl(patron, p$nombre, ignore.case = TRUE)
    if (any(coincide)) {
      pos <- which(coincide)[1]
      if (pos > nrow(p) / 2) {
        p <- p[rev(seq_len(nrow(p))), ]
        message("  sentido invertido: ", nombre_capa)
      }
    }
  }
  
  p$metodo <- "geometria"
  p
}

# --- Ordenamiento de una capa -------------------------------------------

ordenar_capa <- function(archivo, nombre_capa) {
  
  p <- paradas |> filter(id_linea == archivo, capa == nombre_capa)
  t <- trazos  |> filter(id_linea == archivo, capa == nombre_capa)
  
  if (nrow(p) == 0) return(NULL)
  
  ruta <- p$id_ruta[1]
  con_rutero <- !is.na(ruta) && ruta %in% ruteros$id_ruta
  es_r5 <- !is.na(ruta) && ruta == "R5"
  
  r <- if (con_rutero && all(grepl("#\\d{3}", p$nombre))) {
    ordenar_por_rutero(p, ruta)
  } else if (es_r5) {
    ordenar_por_tabla(p, orden_r5)
  } else {
    ordenar_por_geometria(p, t, nombre_capa)
  }
  
  if (is.null(r)) return(NULL)
  
  r$secuencia <- seq_len(nrow(r))
  r
}

# --- Recorrer todas las capas con paradas -------------------------------

combinaciones <- paradas |>
  st_drop_geometry() |>
  distinct(id_linea, capa)

resultados <- list()

for (i in seq_len(nrow(combinaciones))) {
  r <- ordenar_capa(combinaciones$id_linea[i], combinaciones$capa[i])
  if (!is.null(r)) resultados[[length(resultados) + 1]] <- r
}

ordenadas <- bind_rows(resultados) |> st_as_sf()

message("Capas ordenadas: ", length(resultados), " de ", nrow(combinaciones))
message("Paradas con secuencia: ", nrow(ordenadas))
print(table(ordenadas$metodo))

# --- Escribir -----------------------------------------------------------

st_write(ordenadas, "data/processed/paradas_ordenadas.geojson",
         delete_dsn = TRUE, quiet = TRUE)

message("Listo. data/processed/paradas_ordenadas.geojson")