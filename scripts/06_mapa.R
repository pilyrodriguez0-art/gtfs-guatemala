# 06_mapa.R
# Genera el mapa web interactivo que se publica con GitHub Pages.
#
# Notas técnicas aprendidas en el camino:
# 1. Los KML de Google My Maps guardan una coordenada Z (altura) que
#    Leaflet no maneja: hay que quitarla con st_zm().
# 2. CartoDB ahora exige clave de API, y los servidores de OpenStreetMap
#    bloquean las peticiones desde archivos locales por su política de
#    uso. Se usan los mapas base de Esri, gratuitos y sin clave.
# 3. Solo las paradas tienen popup. Si los trazos también lo tuvieran,
#    un clic cerca de una parada podría devolver el recorrido en vez
#    de la parada, lo que confunde.
# 4. La ruta 305 no tiene mapa individual publicado por la Muni, así
#    que sus datos vienen del mapa del sistema.

library(sf)
library(dplyr)
library(leaflet)
library(htmlwidgets)

dir.create("docs", showWarnings = FALSE)

trazos  <- st_read("data/processed/trazos.geojson", quiet = TRUE)
paradas <- st_read("data/processed/paradas_ordenadas.geojson", quiet = TRUE)

# Quitar la coordenada Z
trazos  <- st_zm(trazos,  drop = TRUE)
paradas <- st_zm(paradas, drop = TRUE)

# --- Elegir fuente por ruta ----------------------------------------------
# Los mapas individuales están más actualizados, pero algunas rutas
# solo existen en el mapa del sistema.

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

# --- Colores -------------------------------------------------------------

rutas <- sort(unique(p$id_ruta))

colores <- c(
  "#e6194b", "#3cb44b", "#4363d8", "#f58231", "#911eb4",
  "#1a9e9e", "#f032e6", "#9acd00", "#c77b7b", "#008080",
  "#9a6324", "#800000", "#808000", "#000075"
)[seq_along(rutas)]

names(colores) <- rutas

# --- Etiquetas -----------------------------------------------------------

p$etiqueta <- paste0(
  "<b>", ifelse(p$sistema == "transmetro", "Transmetro", "TuBus"),
  " · Ruta ", sub("^[LR]", "", p$id_ruta), "</b><br>",
  p$nombre
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
  
  if (nrow(tr) > 0) {
    m <- m |> addPolylines(
      data = tr, color = colores[[r]], weight = 4,
      opacity = 0.75, group = nombre_grupo
    )
  }
  
  m <- m |> addCircleMarkers(
    data = pr, radius = 4, color = colores[[r]],
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
      "<span style='color:#555'>Clic en una parada para ver su nombre. ",
      "Usá el control de capas para mostrar u ocultar rutas.</span><br><br>",
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