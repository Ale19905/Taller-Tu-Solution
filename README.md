# Tu Solution

Aplicación Android para gestionar las reparaciones de un taller de dispositivos electrónicos. Desarrollada con **Flutter**, **Drift + SQLite**, **Riverpod** y arquitectura **MVVM**.

Funciona **sin Internet**, guarda los datos localmente y está diseñada para el teléfono compartido por los técnicos del taller.

> **Proyecto académico:** Segundo parcial de Programación para Dispositivos Móviles — Ingeniería Informática, 3.er año. **Entrega:** 22/11/2026, antes de las 23:59.

## Funcionalidades

- **Inicio:** resumen de órdenes, carga de trabajo y alertas de stock.
- **Órdenes:** registrar clientes y equipos, crear órdenes, asignarlas a técnicos y cambiar sus estados.
- **Reparaciones:** guardar diagnósticos, trabajos de mano de obra y repuestos utilizados.
- **Costos:** calcular el total de mano de obra y repuestos, conservando los precios históricos.
- **Inventario:** administrar repuestos, precios, existencias, stock mínimo y movimientos.
- **Historial:** consultar reparaciones anteriores por cliente o dispositivo.
- **Personas:** consultar clientes y configurar los nombres de los tres técnicos.

**Estados de una orden:** `Recibida → En reparación → Lista → Entregada`. Una orden también puede quedar `Cancelada`.

La app no requiere autenticación y no envía mensajes ni presupuestos a los clientes.

## Tecnologías y requisitos

| Componente | Tecnología / versión |
| --- | --- |
| Aplicación | Flutter y Dart |
| Persistencia local | Drift + SQLite |
| Gestión de estado | Riverpod |
| Arquitectura | MVVM (Model–View–ViewModel) |
| Gradle | 8.14.7 |
| Android Gradle Plugin (AGP) | 8.11.1 |
| Kotlin | 2.2.20 |
| Java | JDK 17 |
| Android mínimo | API 23 (Android 6.0) |

Para compilar necesitás **Flutter SDK**, **Android SDK**, **JDK 17** y un teléfono Android con depuración USB habilitada o un emulador. La primera preparación requiere Internet para descargar dependencias.

## Comandos para ejecutar el proyecto

Abrí PowerShell **en la raíz del proyecto**, donde está `pubspec.yaml`, con un teléfono conectado o un emulador abierto. Ejecutá estos comandos **uno debajo del otro, en este orden**:

```powershell
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter devices
flutter run
```

**Importante:** si el proyecto ya está preparado y no cambiaste las dependencias ni el esquema de Drift, para volver a abrir la app alcanza con `flutter run`.

### Generar el APK

Detené `flutter run` con `q` y ejecutá:

```powershell
flutter build apk --release
```

El archivo generado se encuentra en:

```text
build/app/outputs/flutter-apk/app-release.apk
```

Podés copiar el APK al teléfono e instalarlo. Esta versión utiliza **firma de depuración para el modo release**, suficiente para pruebas y la demostración académica; no está configurada para publicarse en Google Play.

### Solo si faltan los archivos de Android

Si estás preparando una copia del proyecto que no contiene el directorio Android completo, ejecutá **una sola vez**, antes de los comandos anteriores:

```powershell
flutter create --platforms=android --org com.tusolution --project-name tu_solution .
```

No ejecutes `flutter create` innecesariamente si la app ya compila, para evitar sobrescribir configuraciones de Android.

## Arquitectura del proyecto

El proyecto sigue el patrón **MVVM**:

```text
Vista (pantallas Flutter)
    ↓
ViewModel (Riverpod)
    ↓
Repositorio (reglas de negocio)
    ↓
Drift (persistencia)
    ↓
SQLite local
```

```text
tu_solution/
├── lib/
│   ├── main.dart
│   ├── core/                  # Tema y formateadores
│   ├── domain/                # Entidades auxiliares
│   ├── data/                  # Base Drift y repositorio
│   └── presentation/
│       ├── pages/             # Pantallas
│       ├── viewmodels/        # Providers y comandos Riverpod
│       └── widgets/           # Formularios y componentes
├── test/                      # Pruebas automatizadas
├── android/                   # Configuración Android
├── scripts/                   # Scripts de preparación
├── docs/capturas/             # Capturas para la entrega
├── .github/workflows/         # Compilación de APK en GitHub
├── pubspec.yaml
└── README.md
```

El archivo `lib/data/workshop_database.g.dart` se **genera automáticamente** mediante `build_runner`; no se edita manualmente.

## Base de datos y reglas de negocio

La información se conserva en una base **SQLite local** mediante Drift.

| Tabla | Contenido |
| --- | --- |
| `Customers` | Clientes y teléfonos |
| `Devices` | Equipos, propietarios y números de serie |
| `Technicians` | Técnicos del taller |
| `RepairOrders` | Órdenes, responsables, estados y diagnósticos |
| `LaborEntries` | Trabajos y costos de mano de obra |
| `SpareParts` | Repuestos, precios y existencias |
| `PartUsages` | Piezas utilizadas y precios aplicados a cada orden |
| `StockMovements` | Entradas, salidas y devoluciones de stock |

Reglas principales:

- Un cliente puede registrar varios equipos y un equipo puede tener múltiples reparaciones.
- Cada orden tiene como máximo un técnico responsable; para cambiarlo se realiza una reasignación.
- Al utilizar un repuesto se descuenta su existencia; no se permite dejar stock negativo.
- Al eliminar un consumo durante la reparación, la pieza vuelve al inventario.
- Hay alerta de stock bajo cuando las existencias son menores o iguales al mínimo configurado.
- El precio de una pieza consumida queda registrado en la orden, aunque luego cambie su precio de catálogo.
- El total de la orden es la suma de la mano de obra y los repuestos.
- Las órdenes entregadas o canceladas quedan en modo consulta.
- Los datos permanecen disponibles sin conexión, pero **desinstalar la app o borrar sus datos puede eliminar el historial local**.
