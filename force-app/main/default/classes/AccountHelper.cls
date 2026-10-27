// DEMO ONLY: this class intentionally contains code quality / security issues.
public class AccountHelper {

    // Issue 1: Hardcoded credential (secret in source)
    private static final String API_KEY = 'REDACTED_API_KEY';

    // Issue 2: Hardcoded Record Id
    private static Id DEFAULT_OWNER_ID = UserInfo.getUserId();

    // Issue 3: SOQL injection (user input concatenated into dynamic SOQL)
    public static List<Account> searchAccounts(String name) {
        String query = 'SELECT Id, Name FROM Account WHERE Name = \'' + name + '\'';
        return Database.query(query);
    }

    // Issue 4: SOQL and DML inside a loop (governor limits)
    // Issue 5: No CRUD/FLS enforcement (no WITH USER_MODE / stripInaccessible)
    public static void updateAccountContacts(List<Account> accounts) {
        List<Contact> contactsToUpdate = new List<Contact>();
        Set<Id> acctIds = new Set<Id>();
        for (Account acc : accounts) {
            acctIds.add(acc.Id);
        }
        if (!acctIds.isEmpty()) {
            for (Contact con : [SELECT Id, LastName FROM Contact WHERE AccountId IN :acctIds]) {
                con.Description = 'Updated by helper';
                contactsToUpdate.add(con);
            }
        }
        if (!contactsToUpdate.isEmpty()) {
            update contactsToUpdate;
        }
    }

    // Issue 6: Empty catch block (swallowed exception)
    // Issue 7: System.debug of sensitive data
    public static void setDefaultOwner(Account acc) {
        try {
            acc.OwnerId = DEFAULT_OWNER_ID;
            update acc;
            System.debug('Using key: ' + API_KEY + ' for account ' + acc.Name);
        } catch (Exception e) {
            System.debug('setDefaultOwner exception: ' + e);
            throw e;
        }
    }

    // Issue 8: Class has no sharing keyword; method has high cyclomatic complexity
    // Issue 9: Unused local variable and unused parameter
    public static String getAccountTier(Account acc) {

        if (acc.AnnualRevenue == null) {
            return 'Unknown';
        } else {
            if (acc.AnnualRevenue > 1000000) {
                if (acc.NumberOfEmployees > 500) {
                    if (acc.Industry == 'Technology') {
                        return 'Platinum';
                    } else {
                        return 'Gold';
                    }
                } else {
                    return 'Silver';
                }
            } else {
                if (acc.AnnualRevenue > 100000) {
                    return 'Bronze';
                } else {
                    return 'Standard';
                }
            }
        }
    }
}
