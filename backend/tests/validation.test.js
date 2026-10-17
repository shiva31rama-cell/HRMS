const test = require('node:test');
const assert = require('node:assert/strict');
const {
  normaliseEmail,
  isValidEmail,
  isStrongEnoughPassword,
  isNonEmptyText,
  isIntegerInRange
} = require('../lib/validation');

test('normaliseEmail trims spaces and lowercases', () => {
  assert.equal(normaliseEmail('  ADMIN@Example.COM  '), 'admin@example.com');
});

test('email validation accepts a normal address and rejects malformed input', () => {
  assert.equal(isValidEmail('student@example.edu'), true);
  assert.equal(isValidEmail('student-at-example'), false);
  assert.equal(isValidEmail(''), false);
});

test('password validation enforces reasonable length bounds', () => {
  assert.equal(isStrongEnoughPassword('LongEnough123!'), true);
  assert.equal(isStrongEnoughPassword('short'), false);
  assert.equal(isStrongEnoughPassword('x'.repeat(129)), false);
});

test('text validation rejects blank and overlong values', () => {
  assert.equal(isNonEmptyText('Room A-101', 40), true);
  assert.equal(isNonEmptyText('   ', 40), false);
  assert.equal(isNonEmptyText('x'.repeat(11), 10), false);
});

test('integer validation prevents invalid room capacities', () => {
  assert.equal(isIntegerInRange('4', 1, 20), true);
  assert.equal(isIntegerInRange(0, 1, 20), false);
  assert.equal(isIntegerInRange(2.5, 1, 20), false);
  assert.equal(isIntegerInRange(21, 1, 20), false);
});
