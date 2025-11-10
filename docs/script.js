const nav = document.querySelector('.nav');
const navLinks = document.querySelector('.nav-links');
const toggle = document.querySelector('.nav-toggle');
const yearEl = document.getElementById('year');
const themeToggle = document.querySelector('.theme-toggle');
const themeText = document.querySelector('.theme-text');
const backToTop = document.querySelector('.back-to-top');
const root = document.documentElement;

if (yearEl) {
  yearEl.textContent = new Date().getFullYear();
}

if (toggle && navLinks) {
  toggle.addEventListener('click', () => {
    navLinks.classList.toggle('is-open');
    toggle.classList.toggle('is-open');
  });

  navLinks.querySelectorAll('a').forEach((link) => {
    link.addEventListener('click', () => {
      navLinks.classList.remove('is-open');
      toggle.classList.remove('is-open');
    });
  });
}

// Theme toggle without localStorage
let currentTheme = 'dark';

const setTheme = (mode) => {
  currentTheme = mode;
  root.setAttribute('data-theme', mode);
  if (themeToggle) {
    themeToggle.dataset.mode = mode;
    themeToggle.setAttribute('aria-pressed', mode === 'dark');
  }
  if (themeText) {
    themeText.textContent = mode === 'dark' ? 'Dark' : 'Light';
  }
};

// Initialize with dark theme
setTheme('dark');

themeToggle?.addEventListener('click', () => {
  const nextTheme = currentTheme === 'dark' ? 'light' : 'dark';
  setTheme(nextTheme);
});

// Handle navbar transparency
const handleScroll = () => {
  if (!nav || !backToTop) return;
  
  const scrolled = window.scrollY > 100;
  nav.classList.toggle('at-top', !scrolled);
  
  const showBackToTop = window.scrollY > 400;
  backToTop.classList.toggle('is-visible', showBackToTop);
};

document.addEventListener('scroll', handleScroll, { passive: true });
handleScroll();

backToTop?.addEventListener('click', () => {
  window.scrollTo({ top: 0, behavior: 'smooth' });
});

// Close mobile menu when clicking outside
document.addEventListener('click', (e) => {
  if (!navLinks || !toggle) return;
  
  const clickedInside = navLinks.contains(e.target) || toggle.contains(e.target);
  
  if (!clickedInside && navLinks.classList.contains('is-open')) {
    navLinks.classList.remove('is-open');
    toggle.classList.remove('is-open');
  }
});
