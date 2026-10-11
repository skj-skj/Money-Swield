/// SMS bodies the domain tests read (phase-9a.md §5.2). The first five are
/// `notes/sms-example/sms.json` (already anonymized: format kept, values
/// fake); `sms.txt` next to it holds real messages and is never copied
/// here. The rest are written for §12's cases.
library;

/// sample #1: UPI "Sent Rs"; the word UPI only in the footer.
const bankSent1 =
    'Sent Rs.150.00\nFrom ABC Bank A/C *1234\nTo GLOBEX TECHNOLOGIES PRIVA\n'
    'On 14/03/26\nRef 100000000001\nNot You?\n'
    'Call 18000000000/SMS BLOCK UPI to 9000000000';

/// sample #2.
const bankSent2 =
    'Sent Rs.75.00\nFrom ABC Bank A/C *1234\nTo Sunrise REFRESHMENT\n'
    'On 14/03/26\nRef 100000000002\nNot You?\n'
    'Call 18000000000/SMS BLOCK UPI to 9000000000';

/// sample #3.
const bankSent3 =
    'Sent Rs.320.00\nFrom ABC Bank A/C *1234\nTo UMBRA MARKETPLACE PRIVATE\n'
    'On 13/03/26\nRef 100000000003\nNot You?\n'
    'Call 18000000000/SMS BLOCK UPI to 9000000000';

/// sample #4: a UPI ATM withdrawal, not a candidate (P9a-35).
const bankAtm =
    'UPI ATM Withdrawal:Rs.5000.\nFrom:ABC Bank A/c 1234\nAt:the bank ATM ATM\n'
    'UPI RRN:012345678904 on 11/03/26\n'
    'Not you? Call 18000000000/SMS BLOCK UPI to 9000000000    ';

/// sample #5: a mandate, UPI only through the UMN's `@ybl`.
const bankMandate =
    'ABC Bank: Rs 12500.00 debited from A/c **1234 towards Example Ceramics '
    'Limited on 28-02-26. Application No. 0123456789abcdef0123456789abcdef, '
    'UMN: fedcba9876543210fedcba9876543210@ybl. If not you, kindly report on '
    '18000000000.';

const creditCardSpend =
    'INR 2,500 spent on Credit Card XX1234 at AMAZON on 01-10-26. '
    'Avl Lmt INR 50,000';

const swiggyUpi = '₹99 paid to swiggy@ybl via UPI';

const threeDecimals = 'Rs 12.345 debited from A/c XX1234';

const noCurrency = 'Your A/c XX1234 is debited by 20.0 on 01-10-26';

const referenceNumber =
    'Rs 100 debited from A/c XX1234. Reference Number 123456789012';

const utrNumber = 'Rs 100 debited from A/c XX1234. UTR number 1234567';

const neftDebit = 'Rs 500 debited from A/c XX1234 by NEFT to Ravi Kumar';

const impsToRavi =
    'Rs 500 debited from A/c XX1234 by IMPS and credited to Ravi';

const gmailMention = 'Rs 500 debited from A/c XX1234. Query? mail x@gmail.com';

const rupayUpi = 'Rs 40 paid by UPI from your RuPay Credit Card XX12 to CAFE';
