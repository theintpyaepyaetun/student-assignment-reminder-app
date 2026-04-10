// Dynamic landing page content
const landingData = {
  schedule: [
    { title: 'Math Project', status: 'Due 3:00 PM' },
    { title: 'English Essay', status: 'Due Tomorrow' },
    { title: 'Biology Quiz Prep', status: 'In Progress' },
  ],
  features: [
    {
      icon: '📅',
      title: 'Smart Scheduling',
      description:
        'Add assignment deadlines quickly and sort tasks by date and priority.',
    },
    {
      icon: '🔔',
      title: 'Helpful Reminders',
      description:
        'Get timely notifications so you can finish work before the due date.',
    },
    {
      icon: '✅',
      title: 'Progress Tracking',
      description:
        'Mark tasks complete and keep a clear view of what is pending.',
    },
    {
      icon: '☁️',
      title: 'Cloud Sync',
      description:
        'Access your assignments anywhere with secure account-based sync.',
    },
  ],
  steps: [
    {
      title: 'Create Your List',
      description: 'Add assignments with subject, due date, and priority level.',
    },
    {
      title: 'Set Reminders',
      description: 'Choose reminder times that match your study routine.',
    },
    {
      title: 'Complete On Time',
      description: 'Follow your plan and check off tasks as you finish them.',
    },
  ],
  testimonials: [
    {
      quote:
        '“This app helped me stop missing deadlines. I now plan my week in minutes.”',
      author: '— Sarah K., Computer Science Student',
    },
    {
      quote:
        '“Simple design, fast to use, and reminders are exactly what I needed during exams.”',
      author: '— Daniel R., Engineering Student',
    },
  ],
};

function renderDynamicContent() {
  const scheduleList = document.getElementById('schedule-list');
  const featuresGrid = document.getElementById('features-grid');
  const stepsGrid = document.getElementById('steps-grid');
  const testimonialsGrid = document.getElementById('testimonials-grid');

  if (scheduleList) {
    scheduleList.innerHTML = landingData.schedule
      .map(
        (item) =>
          `<li><span>${item.title}</span><strong>${item.status}</strong></li>`
      )
      .join('');
  }

  if (featuresGrid) {
    featuresGrid.innerHTML = landingData.features
      .map(
        (feature) => `
          <article class="feature-card">
            <div class="icon" aria-hidden="true">${feature.icon}</div>
            <h3>${feature.title}</h3>
            <p>${feature.description}</p>
          </article>
        `
      )
      .join('');
  }

  if (stepsGrid) {
    stepsGrid.innerHTML = landingData.steps
      .map(
        (step, index) => `
          <article class="step-card">
            <span class="step-number">${index + 1}</span>
            <h3>${step.title}</h3>
            <p>${step.description}</p>
          </article>
        `
      )
      .join('');
  }

  if (testimonialsGrid) {
    testimonialsGrid.innerHTML = landingData.testimonials
      .map(
        (testimonial) => `
          <figure class="testimonial-card">
            <blockquote>${testimonial.quote}</blockquote>
            <figcaption>${testimonial.author}</figcaption>
          </figure>
        `
      )
      .join('');
  }
}

renderDynamicContent();

// Mobile navigation toggle
const menuToggle = document.querySelector('.menu-toggle');
const siteNav = document.querySelector('.site-nav');

if (menuToggle && siteNav) {
  menuToggle.addEventListener('click', () => {
    const isOpen = siteNav.classList.toggle('open');
    menuToggle.setAttribute('aria-expanded', String(isOpen));
  });
}

// Smooth scrolling for in-page navigation links
const navLinks = document.querySelectorAll('a[href^="#"]');

navLinks.forEach((link) => {
  link.addEventListener('click', (event) => {
    const targetId = link.getAttribute('href');
    if (!targetId || targetId === '#') return;

    const target = document.querySelector(targetId);
    if (!target) return;

    event.preventDefault();
    target.scrollIntoView({ behavior: 'smooth', block: 'start' });

    // Close mobile nav after link click
    siteNav?.classList.remove('open');
    menuToggle?.setAttribute('aria-expanded', 'false');
  });
});

// Update footer year automatically
const yearEl = document.getElementById('year');
if (yearEl) {
  yearEl.textContent = String(new Date().getFullYear());
}

// Simple fade/slide reveal animation with Intersection Observer
const revealElements = document.querySelectorAll('.reveal');

const revealObserver = new IntersectionObserver(
  (entries, observer) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        entry.target.classList.add('is-visible');
        observer.unobserve(entry.target);
      }
    });
  },
  { threshold: 0.2 }
);

revealElements.forEach((element) => revealObserver.observe(element));
