**eduLLM** is an open-source, free-license educational quiz platform for classrooms, team sessions, events, and internal training. This repository is an enhanced fork of [MindBuzz](https://github.com/kriziw/MindBuzz), expanding the manager experience with AI-assisted quiz generation, improved question editing, PostgreSQL persistence, and various other improvements over the original project.

> Warning: the project is still under active development. If you hit bugs or have feature ideas, please open an issue in the repository.

## What's Added In This Version (eduLLM)

- **AI-Assisted Quiz Generation (RAG)**: Integration with a RAG system and LLM to automatically generate contextual quizzes for specific subjects.
- **PostgreSQL Persistence**: Fully migrated from SQLite to PostgreSQL (`edu_llm` database) using stored procedures and functions for all data interactions.
- **Student Authentication**: Secure student authentication flow, mapping students to their full names and tracking their game history.
- **Advanced Professor Dashboard**: Professor dashboard for creating, editing, and managing quizzes and subjects (`materias`).
- **Subject Normalization**: System to manage subjects (`materias`) automatically preventing duplicates.
- **Rich Media Support**: In-browser quiz editor for question text, answers, and optional media (audio, video, images).
- **Socket.io Improvements**: Better mobile reconnect recovery for players after app switching or screen lock.
- **SSO/OIDC Support**: Optional generic OpenID Connect (OIDC) / OAuth2 SSO for manager sign-in.

## Architecture & Technology Stack

- **Frontend**: React 19 + Vite + TailwindCSS v4 + Zustand + React Router v7
- **Communication**: Socket.IO v4 (WebSockets)
- **Backend**: Node.js (TypeScript) with native HTTP server
- **Database**: PostgreSQL (`pg`) for accounts, quizzes, and progression, and SQLite for local history support.
- **Authentication**: Custom Password + Optional OIDC/SSO.

## Quick Start

### Docker Compose

The simplest way to run eduLLM is with Docker Compose:

```bash
git clone https://github.com/gusugus/eduLLM.git
cd eduLLM
mkdir -p config media
docker compose -f compose.yml pull
docker compose -f compose.yml up -d
```

The app will be available at [http://localhost:3000](http://localhost:3000).

### Local Development

```bash
git clone https://github.com/gusugus/eduLLM.git
cd eduLLM
pnpm install
pnpm run dev
```

For a production build:

```bash
pnpm run build
pnpm start
```

## Documentation

Full technical documentation can be found in the following files:
- `DOCUMENTATION.md`: Exhaustive reference for architecture, WebSockets, directories, services, and frontend.
- `BBDD_DOCUMENTATION.md`: Database schema, stored procedures, and functions description for PostgreSQL.

## Contributing

1. Fork the repository
2. Create a branch
3. Make your changes
4. Open a pull request

## Attribution

This repository builds on the original [MindBuzz](https://github.com/kriziw/MindBuzz) and [Ralex91/Rahoot](https://github.com/Ralex91/Rahoot) projects. If you are evaluating eduLLM for the first time, please consider checking out the upstream projects and giving credit to the original work as well.

