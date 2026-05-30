# Cómo Ver los Logs de la App en Xcode Console

## Pasos para Ver los Logs:

### 1. Conectar el Apple Watch
- Asegúrate de que tu Apple Watch esté conectado al iPhone
- El iPhone debe estar conectado a tu Mac

### 2. Abrir Xcode y Seleccionar el Dispositivo
1. Abre Xcode
2. En la barra superior, haz clic en el menú desplegable donde dice el nombre del dispositivo/simulador
3. Selecciona tu **Apple Watch** (no el iPhone ni el simulador)
   - Debería aparecer algo como: "Javier's Apple Watch"

### 3. Abrir la Consola
1. En Xcode, ve a la parte inferior de la ventana
2. Si no ves la consola, presiona **⇧⌘Y** (Shift + Command + Y) o ve a **View → Debug Area → Show Debug Area**
3. Deberías ver dos paneles:
   - **Panel izquierdo**: Variables y breakpoints
   - **Panel derecho**: Console (donde aparecen los logs)

### 4. Filtrar los Logs
En la barra de búsqueda de la consola (parte inferior), puedes filtrar por:
- `[GPS]` - Para ver solo los logs relacionados con GPS
- `[Workout]` - Para ver solo los logs del workout
- `✅` - Para ver solo los mensajes de éxito
- `❌` - Para ver solo los errores
- `⚠️` - Para ver solo las advertencias

### 5. Ejecutar la App y Observar los Logs
1. Ejecuta la app en el Apple Watch (⌘R o botón Play)
2. Los logs aparecerán en tiempo real en la consola
3. Busca estos mensajes clave:

#### Al Iniciar el Workout:
- `🚀 [GPS] Iniciando GPS tracking...`
- `🚀 [GPS] RouteBuilder creado`
- `🚀 [GPS] LocationManager iniciado`

#### Cuando se Reciben Ubicaciones:
- `📍 [GPS] didUpdateLocations llamado con X ubicaciones`
- `📍 [GPS] Agregando X ubicaciones válidas al route`
- `✅ [GPS] X ubicaciones agregadas exitosamente al route`

#### Al Finalizar el Workout:
- `🗺️ [GPS] Finalizando ruta GPS con workout guardado...`
- `✅ [GPS] Ruta GPS guardada exitosamente y asociada al workout`

## Logs Importantes a Revisar:

### ✅ Si Todo Funciona Correctamente:
Deberías ver esta secuencia:
1. `🚀 [GPS] Iniciando GPS tracking...`
2. `📍 [GPS] didUpdateLocations llamado con X ubicaciones` (múltiples veces)
3. `✅ [GPS] X ubicaciones agregadas exitosamente al route` (múltiples veces)
4. `🗺️ [GPS] Finalizando ruta GPS...`
5. `✅ [GPS] Ruta GPS guardada exitosamente`

### ❌ Si Hay Problemas:

**Problema: No se reciben ubicaciones**
- Busca: `⚠️ [GPS] No hay ubicaciones válidas para agregar`
- **Causa posible**: GPS no tiene señal, ubicaciones con precisión muy baja, o permisos no concedidos

**Problema: RouteBuilder no disponible**
- Busca: `❌ [GPS] RouteBuilder no está disponible`
- **Causa posible**: El GPS tracking no se inició correctamente

**Problema: Error al guardar la ruta**
- Busca: `❌ [GPS] Error finalizando ruta GPS`
- **Causa posible**: El workout no se guardó correctamente antes de asociar la ruta

**Problema: Autorización denegada**
- Busca: `❌ [GPS] Autorización denegada`
- **Causa posible**: Permisos de ubicación no concedidos

## Tips Adicionales:

1. **Limpiar la Consola**: Presiona el botón de "limpiar" (🗑️) en la consola para ver solo los logs nuevos

2. **Guardar los Logs**: Puedes hacer clic derecho en la consola y seleccionar "Save Console As..." para guardar los logs en un archivo

3. **Buscar Errores Específicos**: Usa ⌘F para buscar texto específico en los logs

4. **Ver Logs del Sistema**: Puedes ver también los logs del sistema del Apple Watch si es necesario

## Nota Importante:

Los logs solo aparecen cuando la app está ejecutándose desde Xcode. Si ejecutas la app directamente desde el Apple Watch (sin Xcode), no verás los logs.


