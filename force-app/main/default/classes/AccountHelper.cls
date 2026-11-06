// DEMO ONLY: this class intentionally contains code quality / performance / tech debt / security issues.
// TODO: clean this up later
public without sharing class AccountHelper {
  // SECURITY: hardcoded credential and endpoint (secret in source)
  private static final String API_KEY = 'demo-not-a-real-key-1234';
  private static final String ADMIN_PASSWORD = 'Admin@12345';
  private static final String ENDPOINT =
    'https://api.partner-demo.com/v1/accounts?key=' + API_KEY;

  // SECURITY: hardcoded record ids
  private static final Id DEFAULT_OWNER_ID = '005000000000001AAA';
  private static final Id DEFAULT_ACCOUNT_ID = '001000000000001AAA';

  // TECH DEBT: stale static state shared across transactions
  public static List<Account> cache = new List<Account>();
  public static Integer counter = 0;

  // SECURITY: SOQL injection (user input concatenated into dynamic SOQL), no CRUD/FLS
  public static List<Account> searchAccounts(String name) {
    String query =
      'SELECT Id, Name, AnnualRevenue, Phone FROM Account WHERE Name = \'' +
      name +
      '\'';
    return Database.query(query);
  }

  // SECURITY: SOQL injection through LIKE and ORDER BY
  public static List<Account> searchAccountsSorted(
    String term,
    String sortField
  ) {
    return Database.query(
      'SELECT Id, Name FROM Account WHERE Name LIKE \'%' +
        term +
        '%\' ORDER BY ' +
        sortField
    );
  }

  // PERFORMANCE: SOQL and DML inside a loop (governor limits)
  // SECURITY: no CRUD/FLS enforcement
  public static void updateAccountContacts(List<Account> accounts) {
    for (Account acc : accounts) {
      List<Contact> contacts = [
        SELECT Id, LastName
        FROM Contact
        WHERE AccountId = :acc.Id
      ];
      for (Contact con : contacts) {
        con.Description = 'Updated by helper';
        update con;
        counter = counter + 1;
      }
    }
  }

  // PERFORMANCE: query with no filter and no LIMIT, selects fields never used
  public static Integer countAllAccounts() {
    List<Account> all = [
      SELECT Id, Name, Phone, Website, Description, BillingStreet, BillingCity
      FROM Account
    ];
    cache = all;
    return all.size();
  }

  // PERFORMANCE: nested loops, O(n*m) matching instead of a Map
  public static List<Contact> findContactsForAccounts(
    List<Account> accounts,
    List<Contact> contacts
  ) {
    List<Contact> result = new List<Contact>();
    for (Account a : accounts) {
      for (Contact c : contacts) {
        if (c.AccountId == a.Id) {
          result.add(c);
        }
      }
    }
    return result;
  }

  // QUALITY: empty catch block (swallowed exception)
  // SECURITY: System.debug of sensitive data
  public static void setDefaultOwner(Account acc) {
    try {
      System.debug(
        'Using admin password ' + ADMIN_PASSWORD + ' and key ' + API_KEY
      );
      acc.OwnerId = DEFAULT_OWNER_ID;
      update acc;
    } catch (Exception e) {
    }
  }

  // SECURITY: callout with credentials in the URL and TLS-unsafe handling, response unchecked
  public static String syncToPartner(Account acc) {
    Http h = new Http();
    HttpRequest req = new HttpRequest();
    req.setEndpoint(ENDPOINT);
    req.setMethod('POST');
    req.setHeader(
      'Authorization',
      'Basic ' +
      EncodingUtil.base64Encode(Blob.valueOf('admin:' + ADMIN_PASSWORD))
    );
    req.setBody(JSON.serialize(acc));
    HttpResponse res = h.send(req);
    System.debug('Partner response: ' + res.getBody());
    return res.getBody();
  }

  // SECURITY: weak hash (MD5) used for a token
  public static String buildToken(String value) {
    return EncodingUtil.convertToHex(
      Crypto.generateDigest('MD5', Blob.valueOf(value))
    );
  }

  // SECURITY: XSS-prone HTML built from unescaped input
  public static String renderAccountHtml(Account acc) {
    return '<div>' +
      acc.Name +
      '</div><script>var id="' +
      acc.Id +
      '";</script>';
  }

  // QUALITY: high cyclomatic complexity, deep nesting, magic numbers
  // QUALITY: unused local variable and unused parameter
  public static String getAccountTier(Account acc, String unusedParam) {
    String unusedLocal = 'never read';
    String tier = 'Unknown';
    if (acc != null) {
      if (acc.AnnualRevenue != null) {
        if (acc.AnnualRevenue > 100000) {
          if (acc.AnnualRevenue > 1000000) {
            if (acc.NumberOfEmployees != null) {
              if (acc.NumberOfEmployees > 500) {
                if (acc.Industry == 'Technology') {
                  tier = 'Platinum';
                } else {
                  if (acc.Industry == 'Finance') {
                    tier = 'Platinum';
                  } else {
                    tier = 'Gold';
                  }
                }
              } else {
                tier = 'Silver';
              }
            } else {
              tier = 'Silver';
            }
          } else {
            tier = 'Bronze';
          }
        } else {
          tier = 'Standard';
        }
      }
    }
    return tier;
  }

  // TECH DEBT: dead code that is commented out and a duplicate of getAccountTier
  /*
    public static String getAccountTierOld(Account acc) {
        if (acc.AnnualRevenue > 1000000) { return 'Gold'; }
        return 'Standard';
    }
    */
  public static String getAccountTier2(Account acc, String unusedParam) {
    String tier = 'Unknown';
    if (acc != null) {
      if (acc.AnnualRevenue != null) {
        if (acc.AnnualRevenue > 100000) {
          if (acc.AnnualRevenue > 1000000) {
            tier = 'Gold';
          } else {
            tier = 'Bronze';
          }
        } else {
          tier = 'Standard';
        }
      }
    }
    return tier;
  }
}
