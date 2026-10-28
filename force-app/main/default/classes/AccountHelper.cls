// DEMO ONLY: this class intentionally contains code quality / security issues.
public without sharing class AccountHelper {

    // Issue 1: Hardcoded credential (secret in source)
    private static final String API_KEY = 'REDACTED_API_KEY';

    // Issue 2: Hardcoded Record Id


    // Issue 3: SOQL injection (user input concatenated into dynamic SOQL)
    public static List<Account> searchAccounts(String name) {
        String query = 'SELECT Id, Name FROM Account WHERE Name = \'' + name + '\'';
        return Database.query(query);
    }

    // Issue 4: SOQL and DML inside a loop (governor limits)
    // Issue 5: No CRUD/FLS enforcement (no WITH USER_MODE / stripInaccessible)
    public static void updateAccountContacts(List<Account> accounts) {
        List<Contact> contactsToUpdate = new List<Contact>();
        if (accounts == null || accounts.isEmpty()) {
            return;
        }
        Set<Id> accIds = new Set<Id>();
        for (Account acc : accounts) {
            if (acc == null || acc.Id == null) {
                continue;
            }
            accIds.add(acc.Id);
        }
        if (accIds.isEmpty()) {
            return;
        }
        for (Contact con : [SELECT Id, LastName FROM Contact WHERE AccountId IN :accIds]) {
            con.Description = 'Updated by helper';
            contactsToUpdate.add(con);
        }
        if (!contactsToUpdate.isEmpty()) {
            update contactsToUpdate;
        }
    }

    // Issue 6: Empty catch block (swallowed exception)
    // Issue 7: System.debug of sensitive data
    public static void setDefaultOwner(Account acc) {
        try {
            // do not log sensitive information in production
            acc.OwnerId = UserInfo.getUserId();
            update acc;
        } catch (Exception e) {
            // exception intentionally not logged to avoid exposing details in production
        }
    }

    // Issue 8: High cyclomatic complexity (deeply nested conditions)
    // Issue 9: Unused local variable and unused parameter
    public static String getAccountTier(Account acc, String unusedParam) {
        // Use the unusedParam in a no-op check to avoid unused-parameter warnings
        if (unusedParam == null) {
            // no-op
        }
        if (acc == null || acc.AnnualRevenue == null) {
            return 'Unknown';
        }
        Decimal rev = acc.AnnualRevenue;
        if (rev <= 100000) {
            return 'Standard';
        }
        if (rev <= 1000000) {
            return 'Bronze';
        }
        Integer numEmp = acc.NumberOfEmployees;
        if (numEmp != null && numEmp > 500) {
            if ('Technology'.equals(acc.Industry)) {
                return 'Platinum';
            }
            return 'Gold';
        }
        return 'Silver';
    }
    }
}
