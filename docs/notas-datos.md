# Notas de fuentes de datos

Registro de qué publica la Municipalidad de Guatemala sobre Transmetro y TuBus, dónde está, y qué falta.

Última actualización: 15 de septiembre de 2026

---

## Transmetro — IDs de mapas (completo)

Los mapas se descargan con:

```
https://www.google.com/maps/d/kml?mid=<ID>&forcekml=1
```

El parámetro `forcekml=1` fuerza KML sin comprimir. Sin él, Google devuelve KMZ.

| Línea | Recorrido | ID del mapa | Estado |
|---|---|---|---|
| L1 | San Sebastián → Centro Cívico Z1 | `1FtqnCdWA93KLFeP-OUwlIOQMMz4Hlt4` | Descargado |
| L2 | Hipódromo del Norte Z2 → San Sebastián Z1 | `1PBO6JzswSAvHnTIeq_H8x9byg8s4CtY` | Descargado |
| L6 | Proyectos Z6 → FEGUA Z1 | `10g1kggPBBdLXtQe8uktVa7C5MqUgZzI` | Descargado |
| L7 | USAC Periférico Z12 → La Merced Z1 | `1OXgeGUJeOdkOHgT2njwDYh6qfDx-oVM` | Descargado |
| L12 | Centra Sur → Plaza Barrios Z1 | `1_8i9Hg4Y-vUg6xIL3IFguG6cW89ZacY` | Descargado |
| L13 | Hangares Z13 → Tipografía Z1 | `1tYEyBE7-b0VIjCt5kSH4m0VEOhjvHNI` | Descargado |
| L18 | Atlántida Z18 → FEGUA Z1 | `1-OyQubHliUnu5TDN_BykelEkVe5fTio` | Descargado |
| Sistema | Mapa completo con estaciones | `1-q3uNeSMBn4WiO04-Ou-9dgfsptXkzE` | Descargado |

**Tamaños al 15/09/2026:** L1 7.9 KB, L2 8.2 KB, L6 17 KB, L7 28.9 KB, L12 24.6 KB, L13 33.4 KB, L18 24.8 KB, sistema 430 KB.

El mapa del sistema pesa catorce veces más que cualquier línea individual. Es el candidato más probable a contener todas las estaciones del sistema, incluidas las de transbordo.

**Dato de vigencia pendiente de verificar:** la estación Parque Colón se integró a la Línea 7 en julio de 2025. Si aparece en `L7.kml`, el mapa es posterior a esa fecha.

---

## TuBus — IDs de mapas (parcial: 4 de 7)

Cada ruta tiene su propia página en `muniguate.com/movilidadurbana/ruta-NNN/`, con un mapa de Google My Maps embebido.

| Ruta | Recorrido | ID del mapa | Estado |
|---|---|---|---|
| 5 | Parque Colón Z1 → Puente de la Penitenciaría Z4 | `1Ut7wqvzMdvqISaWjpnhms6jjMbu4_wc` | Encontrado |
| 104 | Barrio San Antonio Z6 → Cementerio La Villa Z14 | `1i0rnw4_AQ-sJtQiudMC1NsxjmR0Moq4` | Encontrado |
| 105 | Parque Jocotenango Z2 → 9a Av. Z7 | `1sk-gaA8P3bcodCdP2tRf9uMrnXYTNns` | Encontrado |
| 801 | Parque Los Pinos Z7 → Terminal Z9 | `1Lb4SyhD-_PFo5WsHLdPQqo-NEzaZBos` | Encontrado |
| 305 | Blvd. Vista Hermosa Z15 → Terminal Z9 | — | **Pendiente** |
| 402 | Av. Petapa Z12 → Col. Santa Fe Z13 (aeropuerto) | — | **Pendiente** |
| 802 | Parque Los Pinos Z7 → 4a Av. Z1 | — | **Pendiente** |

### Por qué faltan tres

Las páginas `/ruta-305/`, `/ruta-402/` y `/ruta-802/` devuelven 404. Tienen otro slug que no aparece indexado en buscadores. El índice de TuBus (`muniguate.com/movilidadurbana/tubus/`) no se pudo cargar desde fuera por timeout del servidor.

### Cómo completarlas

1. Abrir `muniguate.com/movilidadurbana/tubus/` en el navegador
2. `Ctrl+U` para ver el código fuente
3. `Ctrl+F` y buscar `ruta-` → aparecen los slugs reales de las siete rutas
4. En cada página de ruta, `Ctrl+F` buscando `mid=` → copiar hasta el `&`

Alternativa: buscar `mid=` directamente en el índice de TuBus. Si hay un mapa general embebido, ese ID podría cubrir todas las rutas de una vez.

---

## Hallazgo importante: los PDFs de rutero

Cada ruta de TuBus tiene un PDF llamado **"Mapa y Rutero individual"** que contiene información que los KML probablemente no tienen.

Lo que traen:

- **Paradas numeradas** (`#154`, `#155`, `#156`…) en secuencia a lo largo de la ruta
- **Marcas de paradas compartidas** entre dos o más rutas — esto resuelve los transbordos
- **Tiempos aproximados entre tramos** (el rutero de la 801 indica ±4, ±5 y ±7 minutos)
- **Horarios de operación** por tipo de día
- **Número de versión y fecha de vigencia**

Esto es la materia prima de `stop_times.txt`, que era la pieza que parecía faltar. Está en PDF en vez de en datos estructurados, pero está.

PDFs identificados:

| Ruta | Archivo | Versión |
|---|---|---|
| 5 | `V1-Ruta-5-Tubus_compressed.pdf` | V1 |
| 104 | `V8-Ruta-104-Tubus_compressed.pdf` | V8 |
| 105 | `V1-Mapa-y-Rutero-individual-Ruta-105-c.pdf` | V1, vigente desde marzo 2025 |
| 305 | `V4-Mapa-y-Rutero-individual-Ruta-305-c.pdf` | V4 |
| 402 | `V1-Mapa-y-Rutero-individual-Ruta-402-c.pdf` | V1 |
| 801 | `V4-Mapa-y-Rutero-individual-Ruta-801-c.pdf` | V4, vigente desde marzo 2025 |
| 802 | `V3-Ruta-802-Tubus_compressed.pdf` | V3 |

Todos bajo `muniguate.com/movilidadurbana/wp-content/uploads/sites/33/` con subcarpetas por año y mes.

**Pendiente de decidir:** si extraer las paradas del PDF automáticamente (difícil, es un mapa gráfico) o transcribirlas a mano. Siete rutas con ~40 paradas cada una son unas 280 filas. A mano es tedioso pero factible, y probablemente más confiable.

---

## Horarios recopilados

| Ruta | Lunes a viernes | Sábado | Domingo y festivos |
|---|---|---|---|
| Transmetro (general) | 4:30–5:30 a 20:00–21:00 | igual | reducido |
| TuBus 5 | 5:00–20:00 | 5:00–19:00 | 6:30–19:00 |
| TuBus 104 | 5:30–19:00 (L-S) | 5:30–19:00 | 6:00–18:00 |
| TuBus 105 | 5:30–19:00 (L-S) | 5:30–19:00 | 6:00–18:00 |
| TuBus 305 | 6:00–18:00 todos los días | igual | igual |
| TuBus 402 | 6:00–19:00 (L-S) | 6:00–19:00 | 6:00–18:00 |
| TuBus 801 | 5:30–19:00 (L-S) | 5:30–19:00 | 6:00–18:00 |

Ojo: hay discrepancias entre fuentes para la 104 (una dice 18:00, otra 19:00). Los ruteros oficiales mandan sobre las notas de prensa.

Los horarios indican inicio y fin del servicio **en las paradas extremo** de la ruta, no en paradas intermedias. Esto importa para modelar `frequencies.txt` con honestidad.

---

## Tarifas

- **TuBus:** Q5.00
- **Transmetro:** las fuentes discrepan entre Q1.00 y Q1.50. Verificar en muniguate.com
- Pago con Tarjeta Ciudadana, o tarjeta Visa/Mastercard
- Rutas en fase de prueba han operado gratis en distintos momentos

---

## Cambios anunciados

La Muni lanzó en septiembre de 2025 una licitación por un contrato de operación a 20 años para **17 rutas nuevas de TuBus**, tanto dentro de la ciudad como hacia zonas más alejadas. En marzo de 2026 se anunció que 8 de esas rutas tendrían tarifa de Q7.50, manteniendo Q5.00 para el resto.

Esto va a cambiar la red de forma sustancial. El pipeline está diseñado para absorberlo volviendo a correr los scripts.

---

## Limitaciones conocidas

1. **No se puede verificar la vigencia de los mapas.** Google My Maps no expone fecha de última modificación en el KML. Solo se puede inferir por indicios (presencia de estaciones nuevas).
2. **Errores en las fuentes oficiales.** La página de la Ruta 5 tiene textos alternativos de imagen que describen la Línea 1 del Transmetro — error de copiar y pegar de la Muni. Recordatorio de que las fuentes oficiales no son infalibles.
3. **Faltan 3 de 7 rutas de TuBus.**
4. **Las paradas están en PDF, no en datos.** Los ruteros tienen la información de secuencia, pero en formato gráfico.
5. **No hay GTFS oficial.** Ese es el vacío que este proyecto busca llenar.

---

## Fuentes de actualización

- **Canal de WhatsApp de Transmetro/TuBus MuniGuate**: la vía más rápida para enterarse de desvíos, suspensiones y cambios de horario. No es legible por máquina; sirve como alerta para volver a correr el pipeline.
- `muniguate.com/movilidadurbana/` — páginas oficiales por ruta
- `muniguatealfrente.com` — notas de prensa de la Muni

---

## Próximos pasos

- [ ] Completar los IDs de las rutas 305, 402 y 802
- [ ] Agregar TuBus a `01_descargar.R`
- [ ] Descargar los PDFs de rutero a `data/raw/pdf/`
- [ ] Fase 6: convertir KML a GeoJSON
- [ ] Fase 7: verificar si los KML traen paradas con nombre
- [ ] Decidir cómo extraer las paradas numeradas de los ruteros
