#!/bin/bash

# Script para probar la app en múltiples simuladores de Apple Watch
# Uso: ./test_multiple_watches.sh

echo "🧪 Testing EnduroTimeTracker on multiple Apple Watch simulators..."
echo ""

# Lista de simuladores a probar (UUIDs de los simuladores disponibles)
declare -a WATCH_SIMULATORS=(
    "74F06447-C580-42BC-9DC6-5448128BBAE5"  # Apple Watch Series 11 (46mm)
    "B90645C2-1832-4B83-B5A5-FAB1E1E8A9F0"  # Apple Watch Series 11 (42mm)
    "721866C1-F45F-45CD-AFF5-18E55667B0A0"  # Apple Watch Ultra 3 (49mm)
    "53CA10A8-A892-4867-B927-F16A9A5C0B84"  # Apple Watch SE 3 (44mm)
    "D6951D4A-C51C-496B-9481-E6AA5D0EAE37"  # Apple Watch SE 3 (40mm)
)

# Nombres descriptivos para cada simulador
declare -a WATCH_NAMES=(
    "Series 11 (46mm)"
    "Series 11 (42mm)"
    "Ultra 3 (49mm)"
    "SE 3 (44mm)"
    "SE 3 (40mm)"
)

# Verificar que estamos en el directorio correcto
if [ ! -f "EnduroTimeTracker.xcodeproj/project.pbxproj" ]; then
    echo "❌ Error: No se encontró el proyecto Xcode. Ejecuta este script desde el directorio raíz del proyecto."
    exit 1
fi

echo "📱 Simuladores disponibles para probar:"
for i in "${!WATCH_SIMULATORS[@]}"; do
    echo "   ${WATCH_NAMES[$i]}"
done
echo ""
echo "💡 Para probar manualmente:"
echo "   1. Abre Xcode"
echo "   2. Selecciona el esquema 'EnduroTimeTracker Watch App'"
echo "   3. En el selector de dispositivos, elige cada simulador de la lista"
echo "   4. Ejecuta la app (⌘R) y verifica:"
echo "      - Elementos visibles y accesibles"
echo "      - Textos completos sin cortes"
echo "      - Botones con tamaño adecuado"
echo "      - Transiciones suaves"
echo "      - Pantalla de advertencia se muestra correctamente"
echo ""
echo "📋 Checklist de verificación:"
echo "   ☐ Pantalla Welcome - Logo y botón Start centrados"
echo "   ☐ Pantalla Warning - Icono, texto y checkbox visibles"
echo "   ☐ Menú Principal - Todos los botones accesibles"
echo "   ☐ TimeTable - Lista completa visible sin scroll excesivo"
echo "   ☐ Settings - Navegación funciona correctamente"
echo "   ☐ RaceView - Countdown y controles visibles"
echo ""

# Opción para abrir simuladores automáticamente (requiere Xcode)
read -p "¿Quieres abrir los simuladores ahora? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    for uuid in "${WATCH_SIMULATORS[@]}"; do
        echo "Abriendo simulador $uuid..."
        xcrun simctl boot "$uuid" 2>/dev/null || echo "Simulador ya está corriendo o no disponible"
    done
    echo ""
    echo "✅ Simuladores iniciados. Puedes probar la app desde Xcode."
fi




