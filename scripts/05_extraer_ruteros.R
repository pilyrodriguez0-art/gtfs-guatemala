# 05_extraer_ruteros.R
# Extrae la tabla de paradas de los ruteros en PDF de TuBus.
#
# Cada rutero tiene en su página 3 una tabla con el número de parada,
# la dirección y la zona, en el orden real del recorrido. Esa secuencia
# es lo que necesita stop_times.txt y permite separar ida y vuelta.
#
# Los ruteros de las rutas 5 y 104 son imagen rasterizada y no tienen
# texto extraíble. Para esas dos habrá que usar otro método.
#
# Nota técnica: pdf_text() sobre el documento completo cuelga la sesión
# por el peso de los mapas. Se extrae primero la página 3 a un archivo
# aparte con pdf_subset(), que es una operación liviana.

library(pdftools)
library(dplyr)
library(readr)

dir.create("data/processed", recursive = TRUE, showWarnings = FALSE)

ruteros <- tibble::tribble(
  ~id_ruta, ~archivo,
  "R105",   "V1-Mapa-y-Rutero-individual-Ruta-105-c.pdf",
  "R305",   "V4-Mapa-y-Rutero-individual-Ruta-305-c.pdf",
  "R402",   "V1-Mapa-y-Rutero-individual-Ruta-402-c.pdf",
  "R801",   "V4-Mapa-y-Rutero-individual-Ruta-801-c.pdf",
  "R802",   "V4-Mapa-y-Rutero-individual-Ruta-802-c.pdf"
)

extraer_rutero <- function(id, archivo) {
  
  ruta_pdf <- file.path("data/raw/pdf", archivo)
  if (!file.exists(ruta_pdf)) {
    message("No existe: ", archivo)
    return(NULL)
  }
  
  temporal <- tempfile(fileext = ".pdf")
  pdf_subset(ruta_pdf, pages = 3, output = temporal)
  lineas <- strsplit(pdf_text(temporal), "\n")[[1]]
  unlink(temporal)
  
  filas <- list()
  actual <- NULL
  
  for (l in lineas) {
    
    # Una fila de parada empieza con #NNN
    if (grepl("^\\s*#\\d{3}", l)) {
      
      if (!is.null(actual)) filas[[length(filas) + 1]] <- actual
      
      numero <- sub("^\\s*#(\\d{3}).*", "\\1", l)
      resto  <- sub("^\\s*#\\d{3}\\s*", "", l)
      
      # La zona son los dígitos al final de la línea
      zona <- NA_character_
      if (grepl("\\s\\d{1,2}\\s*$", resto)) {
        zona  <- trimws(sub(".*?\\s(\\d{1,2})\\s*$", "\\1", resto))
        resto <- sub("\\s+\\d{1,2}\\s*$", "", resto)
      }
      
      actual <- list(
        id_ruta   = id,
        n_parada  = numero,
        direccion = trimws(resto),
        zona      = zona
      )
      
    } else if (!is.null(actual) && nchar(trimws(l)) > 3 &&
               !grepl("PARADA|DIRECCIONES|ZONA|CERCAN|RUTA|^\\s*$", l)) {
      # Continuación de una dirección larga
      actual$direccion <- paste(actual$direccion, trimws(l))
    }
  }
  
  if (!is.null(actual)) filas[[length(filas) + 1]] <- actual
  
  if (length(filas) == 0) return(NULL)
  
  resultado <- bind_rows(filas)
  resultado$orden <- seq_len(nrow(resultado))
  message(id, ": ", nrow(resultado), " paradas")
  resultado
}

todos <- bind_rows(
  lapply(seq_len(nrow(ruteros)), function(i) {
    extraer_rutero(ruteros$id_ruta[i], ruteros$archivo[i])
  })
)

message("Total de paradas extraídas: ", nrow(todos))

write_csv(todos, "data/processed/ruteros_tubus.csv")
message("Listo. data/processed/ruteros_tubus.csv")