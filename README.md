# Mesa de Ayuda — CAA Corp (Godot 4.3+)

Port a Godot del prototipo HTML/Three.js `Mesa_de_Ayuda_CAA_Corp_v2.html`.

## Cómo abrirlo
1. Instala Godot 4.3 o superior (versión estándar, no .NET).
2. Importa la carpeta (`project.godot`) y pulsa **F5**.

## Controles
Clic = capturar mouse · Esc = liberarlo / cerrar ventanas · WASD mover · Shift correr · ←/→ girar · **E** interactuar.

## Qué está portado
- Mundo 3D low-poly con las mismas coordenadas: oficina de TI, pasillo, apartamento, data center, 6 departamentos y piso 2 (ascensor, taller, almacén).
- Los 23 tickets, prioridades, SLA, valoración por estrellas, usuarios que te buscan, puestos en sitio y copiadora.
- Escritorio de TI: tickets, habilidades, visor de eventos (SOC), Active Directory, correo/phishing, monitor de red, tablet MFA (TOTP), empleos, tienda y BIOS.
- Consola Cisco IOS completa (user/priv/config/vlan/if, abreviaturas, historial, enable secret, write/erase/reload) con 3 trabajos diarios.
- Taller de reparación (órdenes, diagnóstico, almacén, garantía), llamadas, niveles, rangos, logros, fin de jornada, vida en casa y guardado (`user://itg1.json`).

## No portado (todavía)
Escritorio remoto, navegador y videos simulados, vida/IA de los NPC de la oficina, sonidos y joystick táctil.

## Estructura
- `scripts/game.gd` (autoload `Game`): reglas y estado. `scripts/data.gd` + `data/game_data.json`: datos.
- `scripts/ios_sim.gd`: simulador del switch. `scripts/world.gd`: escena 3D, jugador e interacción.
- `scripts/ui_root.gd`, `desk.gd`, `switch_ui.gd`, `bench_ui.gd`: interfaz.
