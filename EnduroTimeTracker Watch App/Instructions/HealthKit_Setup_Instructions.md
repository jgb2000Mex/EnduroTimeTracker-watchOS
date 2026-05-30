# Instrucciones para Configurar HealthKit en EnduroTimeTracker

## Paso 1: Agregar la Capacidad de HealthKit en Signing & Capabilities

### Para el Watch App Target:

1. **Abre el proyecto en Xcode**
   - Abre `EnduroTimeTracker.xcodeproj` en Xcode

2. **Selecciona el Target del Watch App**
   - En el navegador de proyectos (Project Navigator), haz clic en el proyecto raíz "EnduroTimeTracker"
   - En la lista de TARGETS, selecciona **"EnduroTimeTracker Watch App"** (NO el target del iPhone)

3. **Ve a la pestaña "Signing & Capabilities"**
   - Haz clic en la pestaña "Signing & Capabilities" en la parte superior del editor

4. **Agrega la capacidad HealthKit**
   - Haz clic en el botón **"+ Capability"** en la esquina superior izquierda
   - En el diálogo que aparece, busca y selecciona **"HealthKit"**
   - Haz clic en "Add"

5. **Verifica que HealthKit aparezca**
   - Deberías ver una sección "HealthKit" en la lista de capabilities
   - Asegúrate de que esté habilitada (checkbox marcado)

---

## Paso 2: Agregar Permisos en Info.plist

Como el proyecto usa `GENERATE_INFOPLIST_FILE = YES`, los permisos se agregan directamente en Build Settings o creando un Info.plist.

### Opción A: Agregar en Build Settings (Recomendado)

1. **Con el target "EnduroTimeTracker Watch App" seleccionado**
   - Ve a la pestaña **"Build Settings"**

2. **Busca "Info.plist"**
   - En la barra de búsqueda de Build Settings, escribe: `INFOPLIST_KEY`

3. **Agrega las siguientes claves:**
   
   Haz clic en el botón **"+"** para agregar cada una de estas claves:
   
   **a) NSHealthShareUsageDescription**
   - Key: `INFOPLIST_KEY_NSHealthShareUsageDescription`
   - Type: String
   - Value: `"Necesitamos acceso a tus datos de salud para registrar tu frecuencia cardíaca, calorías, distancia y elevación durante el entrenamiento."`
   
   **b) NSHealthUpdateUsageDescription**
   - Key: `INFOPLIST_KEY_NSHealthUpdateUsageDescription`
   - Type: String
   - Value: `"Necesitamos guardar datos de entrenamiento en HealthKit para registrar tu actividad como 'Enduro Time Tracker'."`
   
   **c) NSLocationWhenInUseUsageDescription**
   - Key: `INFOPLIST_KEY_NSLocationWhenInUseUsageDescription`
   - Type: String
   - Value: `"Necesitamos acceso a tu ubicación para registrar el track GPS de tu entrenamiento."`
   
   **d) NSLocationAlwaysAndWhenInUseUsageDescription**
   - Key: `INFOPLIST_KEY_NSLocationAlwaysAndWhenInUseUsageDescription`
   - Type: String
   - Value: `"Necesitamos acceso continuo a tu ubicación para registrar el track GPS durante todo el entrenamiento, incluso cuando la app está en segundo plano."`

### Opción B: Crear Info.plist manualmente

Si prefieres crear un Info.plist físico:

1. **Crea el archivo Info.plist**
   - En Xcode, haz clic derecho en la carpeta "EnduroTimeTracker Watch App"
   - Selecciona "New File..."
   - Elige "Property List"
   - Nómbralo `Info.plist`
   - Asegúrate de que esté en el target "EnduroTimeTracker Watch App"

2. **Agrega las siguientes claves en Info.plist:**
   
   Abre el archivo Info.plist y agrega estas entradas:
   
   ```xml
   <key>NSHealthShareUsageDescription</key>
   <string>Necesitamos acceso a tus datos de salud para registrar tu frecuencia cardíaca, calorías, distancia y elevación durante el entrenamiento.</string>
   
   <key>NSHealthUpdateUsageDescription</key>
   <string>Necesitamos guardar datos de entrenamiento en HealthKit para registrar tu actividad como 'Enduro Time Tracker'.</string>
   
   <key>NSLocationWhenInUseUsageDescription</key>
   <string>Necesitamos acceso a tu ubicación para registrar el track GPS de tu entrenamiento.</string>
   
   <key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
   <string>Necesitamos acceso continuo a tu ubicación para registrar el track GPS durante todo el entrenamiento, incluso cuando la app está en segundo plano.</string>
   ```

3. **Actualiza Build Settings**
   - Ve a Build Settings del target "EnduroTimeTracker Watch App"
   - Busca "INFOPLIST_FILE"
   - Establece el valor a: `EnduroTimeTracker Watch App/Info.plist`
   - Desmarca "GENERATE_INFOPLIST_FILE" o déjalo como está (ambos funcionan)

---

## Paso 3: Verificar la Configuración

1. **Verifica que HealthKit esté en Capabilities**
   - En Signing & Capabilities, deberías ver "HealthKit" listado

2. **Verifica los permisos**
   - En Build Settings, busca las claves `INFOPLIST_KEY_NSHealthShareUsageDescription` y `INFOPLIST_KEY_NSHealthUpdateUsageDescription`
   - O verifica que existan en Info.plist si usaste la Opción B

3. **Limpia y reconstruye el proyecto**
   - Product → Clean Build Folder (⇧⌘K)
   - Product → Build (⌘B)

---

## Paso 4: Probar en Dispositivo Real

**IMPORTANTE:** HealthKit solo funciona en dispositivos reales, NO en el simulador.

1. **Conecta tu Apple Watch al iPhone**
2. **Ejecuta la app en el Apple Watch**
3. **La primera vez que aparezca WelcomeView, deberías ver el diálogo de permisos de HealthKit**
4. **Acepta los permisos para que la app pueda registrar datos**

---

## Notas Importantes

- **HealthKit requiere un dispositivo real**: No funcionará en el simulador
- **Los permisos se solicitan una vez**: Después de aceptarlos, no se volverán a mostrar a menos que el usuario los revoque en Configuración
- **El workout se registra automáticamente**: Cuando presiones "Go!" y comience la carrera, el workout se iniciará desde el primer Time Control
- **Los datos se guardan en la app Fitness**: Al finalizar la carrera, verás el entrenamiento registrado como "Enduro Time Tracker"

---

## Solución de Problemas

### Si no aparece el diálogo de permisos:
- Verifica que las claves estén correctamente agregadas en Build Settings o Info.plist
- Asegúrate de estar ejecutando en un dispositivo real (no simulador)
- Verifica que HealthKit esté habilitado en Capabilities

### Si hay errores de compilación:
- Limpia el proyecto (⇧⌘K)
- Verifica que el framework HealthKit esté importado en los archivos necesarios
- Asegúrate de que el deployment target sea watchOS 9.0 o superior

### Si el workout no se inicia:
- Verifica que los permisos hayan sido aceptados
- Revisa la consola de Xcode para ver mensajes de error
- Asegúrate de que haya al menos un Time Control configurado

