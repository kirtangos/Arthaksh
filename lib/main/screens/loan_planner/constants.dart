/// Constants for loan planner - single source of truth for hardcoded strings

// Payment frequencies
const String frequencyMonthly = 'Monthly';
const String frequencyQuarterly = 'Quarterly';
const String frequencyHalfYearly = 'Half Yearly';

// Loan types
const String homeLoan = 'Home Loan';

// Payment types
const String regularEMI = 'Regular EMI';

// Loan statuses
const String statusClosed = 'Closed';
const String statusActive = 'Active';
const String statusAll = 'All';

// Firestore field names
const String fieldStatus = 'status';
const String fieldClosedAt = 'closedAt';
const String fieldPaymentType = 'paymentType';

// UI text
const String addInstallment = 'Add Installment';
const String saveInstallment = 'Save Installment';
const String installmentAmount = 'Installment Amount';
const String installmentDate = 'Installment Date';
const String editInstallment = 'Edit Installment';
const String deleteInstallment = 'Delete installment?';
const String installmentUpdated = 'Installment updated';
const String installmentDeleted = 'Installment deleted';
const String loanClosed = 'Loan Closed';
const String addLoan = 'Add Loan';
const String saveLoan = 'Save Loan';

// Validation messages
const String required = 'Required';
const String enterValidNumber = 'Enter a valid number';
const String mustBeGreaterThanZero = 'Must be > 0';
const String mustBeGreaterEqualZero = 'Must be ≥ 0';
const String mustBeLessEqual100 = 'Must be ≤ 100%';
