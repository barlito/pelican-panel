# Pelican Panel — Game Servers Backoffice

[Pelican](https://pelican.dev) (successeur communautaire de Pterodactyl) : web UI pour gérer
tous les serveurs de jeux — édition de conf on the fly, console live, start/stop/restart,
fichiers, planification, backups, et **partage d'accès** avec des comptes par utilisateur.

Premier serveur hébergé : **ARK: Survival Ascended** (voir plus bas).

## Architecture

```
                        ┌─────────────────────────────────────────────┐
 https://panel.b.fr ───▶│ traefik-base (TLS, headers)                 │
 https://wings.b.fr ───▶│                                             │
                        └──────┬──────────────────────┬───────────────┘
                               ▼                      ▼
                        ┌─────────────┐        ┌─────────────┐    docker.sock
                        │   panel     │───────▶│   wings     │──────────────┐
                        │ (web UI,    │  API   │ (daemon)    │              ▼
                        │  SQLite)    │        │ :8080 API   │   ┌────────────────────┐
                        └─────────────┘        │ :2022 SFTP  │   │ conteneurs de jeux │
                                               └─────────────┘   │ ASA :7777/udp ...  │
                                                                 └────────────────────┘
```

- **panel** : l'UI web (Laravel + Caddy embarqué en HTTP, TLS terminé par Traefik).
  SQLite par défaut dans `./pelican-data` — largement suffisant ici, migrable vers MariaDB plus tard.
- **wings** : le daemon qui pilote le **docker du host** via `docker.sock`. Les serveurs de jeux
  sont des conteneurs *siblings* (pas des enfants), leurs données vivent dans `/var/lib/pelican`.
- La console web du panel se connecte en websocket **directement** à `wings.<domain>` (via Traefik).
- Pas d'Authelia sur ces routes : le panel a sa propre auth (+ 2FA), l'API wings est authentifiée
  par tokens, et Authelia casserait l'accès des potes + les appels panel → wings.

## Prérequis

- `traefik-base` déployé (réseau `traefik_traefik_proxy` existant)
- DNS : `panel.barlito.fr` et `wings.barlito.fr` → IP du host
- RAM : **~11-16 Go libres** pour un serveur ASA (UE5, ça ne rigole pas)

## Installation

```bash
cp .env.example .env   # adapter les domaines si besoin
make deploy
```

1. Ouvrir `https://panel.barlito.fr/installer` → créer le compte admin (premier run uniquement).
2. **Admin → Nodes → Create Node** :
   - FQDN : `wings.barlito.fr`, communication en **HTTPS**, **Behind Proxy : ON**
   - Daemon Port `8080`, SFTP `2022`
3. Onglet **Configuration** du node → **Auto Deploy** → copier les arguments, puis :
   ```bash
   make wings-configure TOKEN="--panel-url https://panel.barlito.fr --token XXX --node 1"
   ```
4. Le node doit passer au vert (heartbeat 💚) dans l'admin.

## Serveur ARK: Survival Ascended

> ⚠️ Le binaire serveur ASA est Windows-only : l'egg le fait tourner sous **Proton**
> (couche de compat Valve) dans le conteneur. Aucun serveur Windows requis, c'est transparent.

1. **Admin → Eggs → Import** avec cette URL :
   ```
   https://raw.githubusercontent.com/pelican-eggs/games-steamcmd/main/ark_survival_ascended/egg-a-r-k--survival-ascended.json
   ```
2. **Admin → Servers → Create** avec l'egg ASA :
   - Mémoire : **12-16 Go** (11 Go mini à vide)
   - Allocations : `7777/udp` (game) — le port peer est **toujours game+1** (`7778/udp`), à ouvrir aussi
   - RCON : `37015` (optionnel, interne)
   - Variables : map (`TheIsland_WP`), session name, passwords, PvE/PvP, max players
3. Premier démarrage : steamcmd télécharge ~30 Go, patience.

### Mods — ça a changé depuis ASE 🥚

Fini le Steam Workshop : ASA utilise **CurseForge**. Dans les variables du serveur (onglet
**Startup** — modifiable on the fly puis restart), renseigner `MOD_IDS` avec les **Project IDs**
CurseForge, séparés par des virgules sans espaces :

```
MOD_IDS=929420,940122,939249
```

Le Project ID est affiché sur la page de chaque mod sur
[curseforge.com/ark-survival-ascended](https://www.curseforge.com/ark-survival-ascended).
Les mods sont téléchargés/mis à jour automatiquement au démarrage du serveur.

### Config `.ini` on the fly

`GameUserSettings.ini` et `Game.ini` sont éditables depuis l'onglet **Files** du panel
(`ShooterGame/Saved/Config/WindowsServer/`) — édition dans le navigateur, restart, done.

## Partager les accès 🤝

- Chaque pote crée son compte sur le panel (ou tu les crées : **Admin → Users**).
- Sur le serveur → onglet **Users** → inviter par email avec des **permissions fines** :
  console, start/stop, fichiers, backups… Ils ne voient que ce que tu leur donnes.

## Firewall

`traefik-base` est en default-deny (INPUT + DOCKER-USER) : ouvrir les ports de jeu
publiés par les conteneurs wings — pour ASA : `7777/udp` + `7778/udp` (+ `2022/tcp` pour le SFTP).

## Backups

- Backups par serveur depuis le panel (onglet **Backups**, stockés par wings).
- `make backup` : archive complète (panel data + `/etc/pelican` + `/var/lib/pelican`).

## Roadmap

- [ ] Phase 2 : migrer le serveur Minecraft dans le panel (egg officiel dispo)
- [ ] Phase 3 : migrer Project Zomboid (egg dispo aussi)
- [ ] Alerting Discord via les webhooks du panel
