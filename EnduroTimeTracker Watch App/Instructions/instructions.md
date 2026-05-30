# Descripción de la App

Necesito que actúes como un programador senior experto en desarrollo de Apple Watch apps (watchOS standalone) utilizando Swift y SwiftUI.

Quiero desarrollar una app para carreras de enduro de motociclismo llamada **Enduro Time Tracker** (similar a Enduro Timekeeper en Garmin IQ Store).

Esta app debe permitir al usuario ingresar los tiempos de control para una carrera y luego ejecutar una pantalla principal donde el reloj haga una cuenta regresiva hacia cada control, mostrando el tiempo que falta, y alertando al usuario mediante vibración/haptics cuando esté próximo el control (por ejemplo 2 minutos antes, 1 minuto antes, etc.).

---

## Especificaciones principales

- La app es **standalone watchOS**. No requiere iPhone.
- Debe registrar un workout en HealthKit para capturar:
  - FC (heart rate)
  - calorías
  - distancia
  - GPS route
- Debe permitir ingresar:
  - Si existe Parc Fermé (opcional)
  - Hora de inicio de Parc Fermé (si aplica)
  - Lista de Time Controls
- Validación de la secuencia de horas:
  - Cada TC debe ser estrictamente posterior al anterior
  - Si el usuario edita un TC hacia una hora mayor/menor que rompe secuencia → los TCs posteriores deben borrarse automáticamente
- El usuario puede agregar Time Controls ilimitados (mínimo 2)
- Cada vez que se agrega un TC nuevo → la hora default debe ser +1 minuto del TC anterior
- Cada vez que se edita un TC → recalcula validación
- No se debe permitir ingresar horas en el pasado

---

## Reglas para Parc Fermé

- Hay un toggle en la pantalla de configuración
- Si Parc Fermé está ON:
  - aparece un selector de hora para PF
  - PF debe ser < TC1
- Si Parc Fermé está OFF:
  - no se muestra PF
  - si estaba ON y estaba guardado → se borra el TC PF

---

## Pantalla principal de carrera

- Muestra hora actual pequeña arriba
- Muestra el siguiente TC (nombre) arriba grande
- Muestra cuenta regresiva hacia ese TC grande en el centro
- Muestra abajo el título del TC siguiente y hora objetivo
- Cuando llega a 00:00 exactos:
  - vibración fuerte
  - pantalla muestra “GO!”
  - luego automáticamente pasa al siguiente TC
- Cuando ya no hay más TCs:
  - pantalla muestra “End of Race”
  - botón “Dismiss” → vuelve al menú

---

## Alertas y Haptics

- 2 minutos antes del TC → vibración fuerte
- 1 minuto antes del TC → vibración fuerte
- 0 segundos → vibración fuerte y “GO!”

> No se puede forzar brillo de pantalla (watchOS limita). No se puede forzar sonido arbitrario. Se permite haptics fuertes.

---

## Workout / Background

- Al iniciar carrera → iniciar HKWorkoutSession
- Debe continuar funcionando en background porque es workout mode
- Debe registrar ruta GPS
- Al terminar → guardar workout

---

## Always-On Display

- Cuando el Watch entra en always-on:
  - debe seguir mostrando timer
  - UI simplificada si es necesario (redacted)
- No debe pausar cuenta regresiva

---

## Navegación

- Welcome → Menu
- Menu → TimeTable o Go!
- Go! deshabilitado si no hay 2 TCs válidos (o PF + TC1 + TC2 si PF ON)

---

## Accesibilidad / Localización

- Dynamic Type
- Inglés como base
- español después

---

## Entrega de código

- siempre SwiftUI
- arquitectura clara y simple
- sin librerías externas

---

## Resultado final esperado

Una app lista para publicar en App Store standalone watchOS que:

- Permite configurar PF + TCs de manera simple
- Calcula countdown exacto
- Vibra en los umbrales
- Maneja el flujo completo PF + TC1 + TC2 + … + End
- Guarda workout en HealthKit
- No requiere iPhone
- Funciona en Apple Watch Ultra 3