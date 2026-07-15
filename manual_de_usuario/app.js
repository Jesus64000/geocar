/* app.js - Lógica de la Presentación del Manual de Usuario */

let currentSlide = 1;
const totalSlides = 15;
const presentationContainer = document.getElementById('presentationContainer');
const slideCounter = document.getElementById('slideCounter');
const prevBtn = document.getElementById('prevBtn');
const nextBtn = document.getElementById('nextBtn');

// Inicializa al cargar la página
document.addEventListener('DOMContentLoaded', () => {
  updateSlideView();

  // Escuchar teclas de flechas para navegación fluida
  document.addEventListener('keydown', (e) => {
    if (e.key === 'ArrowRight' || e.key === ' ') {
      nextSlide();
    } else if (e.key === 'ArrowLeft') {
      prevSlide();
    } else if (e.key === 'Escape') {
      // Si está en modo captura y presiona ESC, sale del modo captura
      if (document.body.classList.contains('clean-screenshot-mode')) {
        toggleCleanMode();
      }
    }
  });

  // Escuchar el tamaño de la ventana para auto-escalar la presentación
  window.addEventListener('resize', autoScalePresentation);
  autoScalePresentation();
});

// Cambia al slide siguiente
function nextSlide() {
  if (currentSlide < totalSlides) {
    currentSlide++;
    updateSlideView();
  }
}

// Cambia al slide anterior
function prevSlide() {
  if (currentSlide > 1) {
    currentSlide--;
    updateSlideView();
  }
}

// Actualiza qué slide se muestra y los controles
function updateSlideView() {
  const slides = document.querySelectorAll('.slide');
  slides.forEach(slide => {
    slide.classList.remove('active');
    if (parseInt(slide.getAttribute('data-slide')) === currentSlide) {
      slide.classList.add('active');
    }
  });

  // Actualiza el contador de la interfaz
  slideCounter.textContent = `Diapositiva ${currentSlide} / ${totalSlides}`;

  // Habilita/deshabilita botones según límite
  prevBtn.disabled = (currentSlide === 1);
  nextBtn.disabled = (currentSlide === totalSlides);
}

// Función de auto-escalado para que la presentación encaje en la pantalla sin romperse
function autoScalePresentation() {
  if (document.body.classList.contains('clean-screenshot-mode')) {
    presentationContainer.style.transform = 'none';
    return;
  }

  const windowWidth = window.innerWidth;
  const windowHeight = window.innerHeight;
  const targetWidth = 1120;
  const targetHeight = 700;

  // Calculamos el factor de escala más restrictivo
  const scaleX = windowWidth / (targetWidth + 40);
  const scaleY = windowHeight / (targetHeight + 100);
  const scale = Math.min(scaleX, scaleY, 1); // No escalar a más del 100%

  presentationContainer.style.transform = `scale(${scale})`;
}

// Manejador de error para cargar capturas de pantalla de respaldo en CSS si no existen imágenes en la carpeta images/
function handleImageError(img) {
  img.style.display = 'none'; // Oculta la imagen rota
  const screenNode = img.parentNode;
  const fallbackUI = screenNode.querySelector('.fallback-ui');
  if (fallbackUI) {
    fallbackUI.style.display = 'flex'; // Muestra la maqueta CSS de respaldo
  }
}

// Activa/desactiva el modo de captura limpia (sin controles, barras o botones molestos)
function toggleCleanMode() {
  const body = document.body;
  const isClean = body.classList.contains('clean-screenshot-mode');

  if (isClean) {
    body.classList.remove('clean-screenshot-mode');
    autoScalePresentation();
  } else {
    body.classList.add('clean-screenshot-mode');
    presentationContainer.style.transform = 'none';
  }
}

// Activa/desactiva el modo oscuro
function toggleTheme() {
  const currentTheme = document.documentElement.getAttribute('data-theme');
  const toggleBtn = document.getElementById('themeToggleBtn');
  
  if (currentTheme === 'dark') {
    document.documentElement.removeAttribute('data-theme');
    toggleBtn.textContent = '🌙 Modo Oscuro';
  } else {
    document.documentElement.setAttribute('data-theme', 'dark');
    toggleBtn.textContent = '☀️ Modo Claro';
  }
}
