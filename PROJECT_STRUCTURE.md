# Project Structure - Houssam's Personal FreqUI

This document outlines the structure and purpose of files in this personalized FreqUI repository.

## 📁 Core Directory Structure

```
frequi/
├── 📄 README.md                    # Personal repository overview
├── 📄 setup_personal.bat          # Windows setup script
├── 📄 setup_personal.sh           # Linux/Mac setup script
├── 📄 .gitignore                  # Git ignore rules (enhanced)
├── 📄 package.json                # Node.js dependencies
├── 📄 vite.config.ts              # Vite build configuration
├── 📄 docker-compose.yml          # Docker setup
├── 📁 src/                        # 🌟 Main application source
│   ├── 📄 App.vue                 # Root Vue component
│   ├── 📄 main.ts                 # Application entry point
│   ├── 📁 components/             # Vue components
│   ├── 📁 composables/            # Vue composition functions
│   ├── 📁 stores/                 # Pinia state management
│   ├── 📁 views/                  # Page components
│   ├── 📁 router/                 # Vue Router configuration
│   ├── 📁 types/                  # TypeScript type definitions
│   ├── 📁 utils/                  # Utility functions
│   └── 📁 assets/                 # Static assets
├── 📁 public/                     # Public static files
├── 📁 e2e/                        # End-to-end tests
└── 📁 tests/                      # Unit tests
```

## 🎨 Personal Customizations

### Custom Components
- **EMA Charts**: Enhanced EMA visualization components
- **Personal Dashboard**: Tailored trading dashboard layout
- **Custom Alerts**: Personal notification system
- **Theme Enhancements**: Custom color schemes and styling

### Key Files for Customization
- `src/components/charts/` - Custom chart components
- `src/views/Dashboard.vue` - Main dashboard view
- `src/stores/` - Application state management
- `src/assets/` - Custom themes and styling

## 🔧 Configuration Files

### Core Configuration
- `package.json` - Dependencies and scripts
- `vite.config.ts` - Build and development server config
- `tsconfig.json` - TypeScript configuration
- `tailwind.config.js` - Tailwind CSS configuration

### Personal Configuration
- `config.personal.json` - Personal settings (not tracked by git)
- `.env.local` - Local environment variables

## 🚀 Development Workflow

### Quick Start
1. **Setup**: `./setup_personal.sh` (Linux/Mac) or `setup_personal.bat` (Windows)
2. **Develop**: `pnpm run dev`
3. **Build**: `pnpm run build`
4. **Test**: `pnpm run test`

### Key Scripts
- `pnpm run dev` - Start development server with hot reload
- `pnpm run build` - Build for production
- `pnpm run preview` - Preview production build
- `pnpm run lint` - Lint and fix code
- `pnpm run test:unit` - Run unit tests
- `pnpm run test:e2e` - Run end-to-end tests

## 📊 Integration Points

### Freqtrade API Integration
- **Backend**: Connects to my personal Freqtrade bot
- **Real-time Data**: WebSocket connection for live updates
- **Custom Endpoints**: Integration with my EMA Redis scripts

### Custom Features
- **EMA Visualization**: Charts displaying my custom EMA calculations
- **Personal Metrics**: Custom trading performance indicators
- **Alert System**: Notifications for my specific trading signals

## 🎨 Theming & Styling

### CSS Framework
- **Tailwind CSS**: Utility-first CSS framework
- **PrimeVue**: Vue.js UI component library
- **Custom Themes**: Personal color schemes

### Customization Areas
- `src/assets/styles/` - Global styles and themes
- `src/components/` - Component-specific styling
- Custom CSS variables for personal branding

## 📱 Responsive Design

The UI is optimized for:
- 💻 **Desktop**: Full dashboard experience
- 📱 **Mobile**: Touch-friendly trading interface
- 📊 **Tablet**: Optimized chart viewing

## 🔗 Related Repositories

- 🤖 [Personal Freqtrade Bot](https://github.com/houssamboudiar/freqtrade)
- 📊 Custom EMA scripts integration
- ⚙️ Trading strategy configurations

---

*This is a personal fork of [FreqUI](https://github.com/freqtrade/frequi) customized by Houssam Boudiar for personal trading dashboard needs.*
