// DEMO ONLY: this class intentionally contains code quality / security issues.
public without sharing class AccountHelper {

    // Issue 1: Hardcoded credential (secret in source)
    private static final String API_KEY = 'REDACTED_API_KEY';

    // Issue 2: Hardcoded Record Id
    private static final Id DEFAULT_ACCOUNT_ID = '001000000000001AAA';

    // Issue 3: SOQL injection (user input concatenated into dynamic SOQL)
    public static List<Account> searchAccounts(String name) {
        String query = 'SELECT Id, Name FROM Account WHERE Name = \'' + name + '\'';
        return Database.query(query);
    }

    // Issue 4: SOQL and DML inside a loop (governor limits)
    // Issue 5: No CRUD/FLS enforcement (no WITH USER_MODE / stripInaccessible)
    public static void updateAccountContacts(List<Account> accounts) {
        for (Account acc : accounts) {
            List<Contact> contacts = [SELECT Id, LastName FROM Contact WHERE AccountId = :acc.Id];
            for (Contact con : contacts) {
                con.Description = 'Updated by helper';
                update con;
            }
        }
    }

    // Issue 6: Empty catch block (swallowed exception)
    // Issue 7: System.debug of sensitive data
    public static void setDefaultOwner(Account acc) {
        try {
            System.debug('Using key: ' + API_KEY + ' for account ' + acc);
            acc.OwnerId = UserInfo.getUserId();
            update acc;
        } catch (Exception e) {
        }
    }

    // Issue 8: High cyclomatic complexity (deeply nested conditions)
    // Issue 9: Unused local variable and unused parameter
    public static String getAccountTier(Account acc, String unusedParam) {
        String unusedVar = 'never used';
        if (acc != null) {
            if (acc.AnnualRevenue != null) {
                if (acc.AnnualRevenue > 1000000) {
                    if (acc.NumberOfEmployees != null && acc.NumberOfEmployees > 500) {
                        if ('Technology'.equals(acc.Industry)) {
                            return 'Platinum';
                        } else {
                            return 'Gold';
                        }
                    } else {
                        return 'Silver';
                    }
                } else if (acc.AnnualRevenue > 100000) {
                    return 'Bronze';
                } else {
                    return 'Standard';
                }
            }
        }
        return 'Unknown';
    }
}
