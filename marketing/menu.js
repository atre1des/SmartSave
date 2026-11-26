'use strict';
const toggle = document.querySelector('.menu-toggle');
const navigation = document.querySelector('#nav');
const compact = matchMedia('(max-width: 760px)');

function setMenu(open) {
  toggle.setAttribute('aria-expanded', String(open));
  navigation.hidden = compact.matches && !open;
}

function updateLayout() {
  toggle.hidden = !compact.matches;
  setMenu(false);
}

updateLayout();
compact.addEventListener('change', updateLayout);
toggle.addEventListener('click', () => setMenu(toggle.getAttribute('aria-expanded') !== 'true'));
navigation.addEventListener('click', (event) => {
  if (!compact.matches || !event.target.closest('a')) return;
  setMenu(false);
  toggle.focus({ preventScroll: true });
});
document.addEventListener('keydown', (event) => {
  if (event.key === 'Escape' && toggle.getAttribute('aria-expanded') === 'true') {
    setMenu(false);
    toggle.focus();
  }
});
