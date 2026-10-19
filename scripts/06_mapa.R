# 06_mapa.R
# Genera el mapa web interactivo que se publica con GitHub Pages.
#
# Notas técnicas aprendidas en el camino:
# 1. Los KML de Google My Maps guardan una coordenada Z (altura) que
#    Leaflet no maneja: hay que quitarla con st_zm().
# 2. CartoDB exige clave de API, y los servidores de OpenStreetMap
#    bloquean las peticiones desde archivos locales por su política de
#    uso. Se usan los mapas base de Esri, gratuitos y sin clave.
# 3. Solo las paradas tienen popup. Si los trazos también lo tuvieran,
#    un clic cerca de una parada podría devolver el recorrido en vez
#    de la parada, lo que confunde.
# 4. La ruta 305 no tiene mapa individual publicado por la Muni, así
#    que sus datos vienen del mapa del sistema.
# 5. Los colores siguen la señalética oficial del Transmetro. Los de
#    TuBus se eligieron con contraste suficiente entre rutas vecinas.

library(sf)
library(dplyr)
library(leaflet)
library(htmlwidgets)

dir.create("docs", showWarnings = FALSE)

trazos  <- st_read("data/processed/trazos.geojson", quiet = TRUE)
paradas <- st_read("data/processed/paradas_ordenadas.geojson", quiet = TRUE)

trazos  <- st_zm(trazos,  drop = TRUE)
paradas <- st_zm(paradas, drop = TRUE)

# --- Elegir fuente por ruta ----------------------------------------------

rutas_con_mapa <- paradas |>
  st_drop_geometry() |>
  filter(id_linea != "sistema", !is.na(id_ruta)) |>
  distinct(id_ruta) |>
  pull(id_ruta)

elegir_fuente <- function(d) {
  d |> filter(
    !is.na(id_ruta),
    (id_linea != "sistema") |
      (id_linea == "sistema" & !(id_ruta %in% rutas_con_mapa))
  )
}

t <- elegir_fuente(trazos)
p <- elegir_fuente(paradas)

# --- Colores oficiales ---------------------------------------------------
# Transmetro: según la señalética de la Muni.
# TuBus: elegidos para contrastar entre sí y con el Transmetro.

colores <- c(
  L1   = "#6a1b9a",   # morado
  L2   = "#2e7d32",   # verde
  L6   = "#ef6c00",   # naranja
  L7   = "#c62828",   # rojo
  L12  = "#1565c0",   # azul
  L13  = "#f9a825",   # amarillo
  L18  = "#00acc1",   # celeste
  R5   = "#ad1457",   # magenta
  R104 = "#558b2f",   # verde oliva
  R105 = "#4527a0",   # índigo
  R305 = "#00695c",   # verde azulado
  R402 = "#5d4037",   # café
  R801 = "#283593",   # azul oscuro
  R802 = "#d84315"    # terracota
)

rutas <- sort(unique(p$id_ruta))

# --- Etiquetas -----------------------------------------------------------
# Incluye la dirección cuando la fuente la trae.

p$etiqueta <- paste0(
  "<div style='font-family:sans-serif;font-size:13px;line-height:1.5'>",
  "<b>", ifelse(p$sistema == "transmetro", "Transmetro", "TuBus"),
  " · Ruta ", sub("^[LR]", "", p$id_ruta), "</b><br>",
  "<b style='font-size:14px'>", p$nombre, "</b>",
  ifelse(
    is.na(p$direccion) | p$direccion == "",
    "",
    paste0("<br><span style='color:#555'>", p$direccion, "</span>")
  ),
  "<br><span style='color:#999;font-size:11px'>Parada ", p$secuencia,
  " del recorrido</span></div>"
)

# --- Construir el mapa ---------------------------------------------------

m <- leaflet() |>
  addProviderTiles(providers$Esri.WorldGrayCanvas) |>
  setView(lng = -90.52, lat = 14.62, zoom = 12)

grupos <- character(0)

for (r in rutas) {
  tr <- t |> filter(id_ruta == r)
  pr <- p |> filter(id_ruta == r)
  
  sistema <- pr$sistema[1]
  nombre_grupo <- paste0(
    ifelse(sistema == "transmetro", "Transmetro ", "TuBus "),
    sub("^[LR]", "", r)
  )
  grupos <- c(grupos, nombre_grupo)
  
  color_r <- unname(colores[r])
  
  if (nrow(tr) > 0) {
    m <- m |> addPolylines(
      data = tr, color = color_r, weight = 4,
      opacity = 0.75, group = nombre_grupo
    )
  }
  
  m <- m |> addCircleMarkers(
    data = pr, radius = 4, color = color_r,
    stroke = TRUE, weight = 1.5, fillColor = "#ffffff",
    fillOpacity = 1, popup = ~etiqueta, group = nombre_grupo
  )
}

m <- m |>
  addLayersControl(
    overlayGroups = grupos,
    options = layersControlOptions(collapsed = TRUE)
  ) |>
  addControl(
    html = paste0(
      "<div style='background:white;padding:10px;font-family:sans-serif;",
      "font-size:12px;max-width:250px;line-height:1.4'>",
      "<b style='font-size:14px'>Transmetro y TuBus</b><br>",
      "Ciudad de Guatemala<br><br>",
      "<span style='color:#555'>Clic en una parada para ver su nombre ",
      "y dirección. Usá el control de capas para mostrar u ocultar ",
      "rutas.</span><br><br>",
      "<span style='color:#888;font-size:11px'>Datos: Municipalidad de ",
      "Guatemala</span></div>"
    ),
    position = "topright"
  )

# --- Guardar -------------------------------------------------------------

saveWidget(
  m,
  file = file.path(normalizePath("docs"), "index.html"),
  selfcontained = TRUE,
  title = "Transmetro y TuBus - Ciudad de Guatemala"
)

message("Mapa guardado en docs/index.html")
message("Rutas dibujadas: ", length(rutas))