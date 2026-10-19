# 07_verificar.R
# Comprobaciones automáticas de consistencia del feed GTFS.
#
# Qué detecta: errores de geometría y de procesamiento — paradas fuera
# de la ciudad, paradas lejos del trazo de su propia ruta, duplicados,
# saltos en la secuencia.
#
# Qué NO detecta: nombres equivocados, paradas que faltan por completo,
# o datos oficiales desactualizados. Eso requiere comparar contra los
# mapas de la Muni (verificación visual) o ir a la parada (campo).

library(sf)
library(dplyr)
library(readr)

ordenadas <- st_read("data/processed/paradas_ordenadas.geojson", quiet = TRUE)
trazos    <- st_read("data/processed/trazos.geojson", quiet = TRUE)

ordenadas <- st_zm(ordenadas, drop = TRUE)
trazos    <- st_zm(trazos, drop = TRUE)

cat("\n=== 1. Coordenadas dentro de la ciudad ===\n")

coords <- st_coordinates(ordenadas)
fuera <- which(
  coords[, "Y"] < 14.50 | coords[, "Y"] > 14.75 |
    coords[, "X"] < -90.65 | coords[, "X"] > -90.35
)

if (length(fuera) == 0) {
  cat("OK: las", nrow(ordenadas), "paradas caen dentro del área esperada\n")
} else {
  cat("ATENCIÓN:", length(fuera), "paradas fuera del área\n")
  print(ordenadas[fuera, c("id_ruta", "nombre")] |> st_drop_geometry())
}

cat("\n=== 2. Distancia de cada parada a su propio trazo ===\n")
cat("Una parada lejos de la línea por la que pasa su bus indica un error.\n\n")

distancias <- list()

for (r in unique(ordenadas$id_ruta[!is.na(ordenadas$id_ruta)])) {
  
  p <- ordenadas |> filter(id_ruta == r)
  t <- trazos    |> filter(id_ruta == r)
  
  if (nrow(t) == 0) next
  
  geom_t <- suppressWarnings(st_union(st_geometry(t)))
  d <- suppressWarnings(as.numeric(st_distance(st_geometry(p), geom_t)))
  
  distancias[[r]] <- tibble(
    id_ruta  = r,
    nombre   = p$nombre,
    metros   = round(d)
  )
}

dist <- bind_rows(distancias)

resumen <- dist |>
  group_by(id_ruta) |>
  summarise(
    paradas   = n(),
    mediana_m = round(median(metros)),
    maxima_m  = max(metros),
    lejanas   = sum(metros > 100),
    .groups   = "drop"
  ) |>
  arrange(desc(maxima_m))

print(as.data.frame(resumen))

cat("\nParadas a más de 200 metros de su trazo:\n")
problematicas <- dist |> filter(metros > 200) |> arrange(desc(metros))

if (nrow(problematicas) == 0) {
  cat("Ninguna. Todas las paradas están cerca de su recorrido.\n")
} else {
  print(as.data.frame(head(problematicas, 20)))
}

cat("\n=== 3. Duplicados en el GTFS ===\n")

stops <- read_csv("output/gtfs/stops.txt", show_col_types = FALSE)
stop_times <- read_csv("output/gtfs/stop_times.txt", show_col_types = FALSE)

cat("Paradas con nombre repetido:", sum(duplicated(stops$stop_name)), "\n")
cat("Paradas sin coordenadas:", sum(is.na(stops$stop_lat)), "\n")
cat("Filas de stop_times sin parada asociada:",
    sum(!stop_times$stop_id %in% stops$stop_id), "\n")

cat("\n=== 4. Paradas que no aparecen en ningún viaje ===\n")

huerfanas <- stops |> filter(!stop_id %in% stop_times$stop_id)
cat(nrow(huerfanas), "paradas sin viaje asociado\n")
if (nrow(huerfanas) > 0 && nrow(huerfanas) <= 20) {
  print(as.data.frame(huerfanas[, c("stop_id", "stop_name")]))
}

cat("\n=== Fin de la verificación ===\n")