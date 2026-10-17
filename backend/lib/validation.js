function normaliseEmail(value) {
  return typeof value === 'string' ? value.trim().toLowerCase() : '';
}

function isValidEmail(value) {
  const email = normaliseEmail(value);
  return email.length <= 254 && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

function isStrongEnoughPassword(value) {
  return typeof value === 'string' && value.length >= 8 && value.length <= 128;
}

function isNonEmptyText(value, maxLength = 160) {
  return typeof value === 'string' && value.trim().length > 0 && value.trim().length <= maxLength;
}

function isIntegerInRange(value, min = 1, max = 100) {
  const number = Number(value);
  return Number.isInteger(number) && number >= min && number <= max;
}

module.exports = {
  normaliseEmail,
  isValidEmail,
  isStrongEnoughPassword,
  isNonEmptyText,
  isIntegerInRange
};
