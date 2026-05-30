# Guía de Pruebas en Múltiples Apple Watch

Esta guía te ayudará a verificar que la app funciona correctamente en diferentes modelos de Apple Watch.

## 📱 Simuladores Disponibles

Tienes los siguientes simuladores configurados:

1. **Apple Watch Series 11 (46mm)** - Pantalla más grande
2. **Apple Watch Series 11 (42mm)** - Pantalla mediana  
3. **Apple Watch Ultra 3 (49mm)** - Pantalla extra grande
4. **Apple Watch SE 3 (44mm)** - Pantalla grande, modelo económico
5. **Apple Watch SE 3 (40mm)** - Pantalla más pequeña

## 🧪 Método 1: Prueba Manual en Xcode (Recomendado)

### Pasos:

1. **Abre el proyecto en Xcode**
   ```bash
   open EnduroTimeTracker.xcodeproj
   ```

2. **Selecciona el esquema correcto**
   - En la barra superior, asegúrate de que el esquema sea "EnduroTimeTracker Watch App"

3. **Cambia el simulador**
   - Haz clic en el selector de dispositivos (junto al botón Run)
   - Selecciona "Add Additional Simulators..." o elige directamente un simulador de la lista

4. **Ejecuta la app**
   - Presiona `⌘R` o haz clic en el botón Run
   - Espera a que la app se compile e instale

5. **Prueba cada pantalla**
   - Navega por todas las pantallas
   - Verifica que los elementos sean visibles y accesibles
   - Toma screenshots si es necesario para comparar

### Checklist de Verificación:

#### Pantalla Welcome
- [ ] Logo centrado y visible
- [ ] Texto de bienvenida completo
- [ ] Botón "Start" accesible y centrado

#### Pantalla Warning (primera vez)
- [ ] Icono de advertencia centrado y visible
- [ ] Texto completo sin cortes
- [ ] Checkbox "No volver a mostrar" accesible
- [ ] Botón "Listo" visible y accesible
- [ ] Todo cabe en pantalla sin scroll

#### Menú Principal
- [ ] Título "Menú Principal" visible debajo del reloj
- [ ] Botón "Tiempos Ideales" completo y accesible
- [ ] Botón "Cronómetro" completo y accesible
- [ ] Botón "Configuración" completo y accesible
- [ ] Botón de back visible en la esquina superior izquierda

#### TimeTable
- [ ] Título "Tiempos Ideales" visible
- [ ] Toggle de "Parque Cerrado" accesible
- [ ] Lista de Time Controls visible
- [ ] Botón "Agregar Punto Control" visible
- [ ] Botón "Cronómetro" al final visible
- [ ] Todo cabe en pantalla con scroll suave

#### Settings
- [ ] Título "Configuración" visible
- [ ] Botón "Cambiar Idioma" accesible
- [ ] Botón "Versión" accesible
- [ ] Navegación funciona correctamente

#### RaceView
- [ ] Countdown visible y legible
- [ ] Título del Time Control visible (puede estar en 2 líneas)
- [ ] Botones del toolbar accesibles
- [ ] Pantalla de bloqueo funciona

## 🚀 Método 2: Script Automatizado

Ejecuta el script de prueba:

```bash
./test_multiple_watches.sh
```

Este script:
- Lista todos los simuladores disponibles
- Proporciona un checklist de verificación
- Puede iniciar los simuladores automáticamente

## 📊 Qué Verificar en Cada Tamaño

### Pantallas Pequeñas (40mm, 42mm)
- ✅ Los textos no se cortan
- ✅ Los botones son lo suficientemente grandes para tocar
- ✅ No hay elementos fuera de la pantalla
- ✅ El scroll funciona suavemente

### Pantallas Medianas (44mm, 46mm)
- ✅ El espaciado se ve equilibrado
- ✅ Los elementos no están demasiado separados
- ✅ La información es fácil de leer

### Pantallas Grandes (49mm - Ultra)
- ✅ Los elementos no se ven demasiado pequeños
- ✅ El espaciado es apropiado
- ✅ La información está bien distribuida

## 🐛 Problemas Comunes y Soluciones

### Problema: Texto cortado
**Solución:** Ajusta `lineLimit` y `minimumScaleFactor` en los Text views

### Problema: Botones muy pequeños
**Solución:** Verifica que usen `.standardButtonHeight` de AppStyles

### Problema: Elementos fuera de pantalla
**Solución:** Revisa los `padding` y `Spacer` en los VStack/HStack

### Problema: Scroll excesivo
**Solución:** Reduce los espaciados entre elementos

## 📸 Tomar Screenshots para Comparar

Para documentar las diferencias:

1. En el simulador, presiona `⌘S` para tomar screenshot
2. Los screenshots se guardan en el escritorio
3. Compara las imágenes entre diferentes tamaños

## 🔍 Comandos Útiles

### Listar todos los simuladores disponibles
```bash
xcrun simctl list devices available | grep -i watch
```

### Iniciar un simulador específico
```bash
xcrun simctl boot "UUID_DEL_SIMULADOR"
```

### Cerrar todos los simuladores
```bash
xcrun simctl shutdown all
```

### Ver simuladores corriendo
```bash
xcrun simctl list devices | grep Booted
```

## ✅ Resultado Esperado

Después de probar en todos los simuladores, deberías confirmar que:

1. ✅ La app funciona correctamente en todos los tamaños
2. ✅ Los elementos son accesibles y visibles
3. ✅ Las transiciones son suaves
4. ✅ No hay crashes o errores
5. ✅ La experiencia de usuario es consistente

---

**Nota:** Si encuentras problemas específicos en algún tamaño, documenta el problema y el tamaño de pantalla para poder ajustarlo.




