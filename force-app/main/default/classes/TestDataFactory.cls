/**
 * Builds test records with only the required fields, plus the values a test cares about.
 */
@IsTest
public class TestDataFactory {
  public static final String MINIMUM_ACCESS_PROFILE = 'Minimum Access - Salesforce';

  /**
   * @param names one account per name
   * @param doInsert insert the records when true
   * @return the accounts
   */
  public static List<Account> createAccounts(
    List<String> names,
    Boolean doInsert
  ) {
    // NOPMD
    // NOPMD
    // NOPMD
    List<Account> accounts = new List<Account>();
    for (String name : names) {
      accounts.add(new Account(Name = name));
    }
    if (doInsert) {
      insert accounts;
    }
    return accounts;
  }

  /**
   * @param accounts one contact per account, same position
   * @param emails email for each contact, same position
   * @param doInsert insert the records when true
   * @return the contacts
   */
  public static List<Contact> createContacts(
    List<Account> accounts,
    List<String> emails,
    Boolean doInsert
  ) {
    // NOPMD
    // NOPMD
    // NOPMD
    List<Contact> contacts = new List<Contact>();
    for (Integer index = 0; index < accounts.size(); index++) {
      contacts.add(
        new Contact(
          LastName = 'Test Contact ' + index,
          Email = emails[index],
          AccountId = accounts[index].Id
        )
      );
    }
    if (doInsert) {
      insert contacts;
    }
    return contacts;
  }

  /**
   * @param billToContacts one draft order per contact, on the contact's account
   * @param fulfillmentStatus fulfillment status and expected delivery date for every order
   * @param doInsert insert the records when true
   * @return the orders
   */
  public static List<Order> createOrders( // NOPMD
    List<Contact> billToContacts,
    String fulfillmentStatus,
    Date expectedDeliveryDate,
    Boolean doInsert
  ) {
    // NOPMD
    // NOPMD
    // NOPMD
    List<Order> orders = new List<Order>();
    for (Contact billToContact : billToContacts) {
      orders.add(
        new Order(
          AccountId = billToContact.AccountId,
          BillToContactId = billToContact.Id,
          Status = 'Draft',
          EffectiveDate = Date.today(),
          Fulfillment_Status__c = fulfillmentStatus,
          Expected_Delivery_Date__c = expectedDeliveryDate
        )
      );
    }
    if (doInsert) {
      insert orders;
    }
    return orders;
  }

  /**
   * Builds users on the Minimum Access profile. Insert them inside System.runAs to
   * avoid mixed DML with business records.
   * @param lastNames one user per last name
   * @param doInsert insert the records when true
   * @return the users
   */
  public static List<User> createMinimumAccessUsers(
    List<String> lastNames,
    Boolean doInsert
  ) {
    // NOPMD
    // NOPMD
    // NOPMD
    Id profileId = [
      SELECT Id
      FROM Profile
      WHERE Name = :MINIMUM_ACCESS_PROFILE
      LIMIT 1
    ]
    .Id;
    String uniqueSuffix = String.valueOf(Crypto.getRandomInteger()).remove('-');
    List<User> users = new List<User>();
    for (Integer index = 0; index < lastNames.size(); index++) {
      String alias = ('tu' + index + uniqueSuffix).left(8);
      users.add(
        new User(
          LastName = lastNames[index],
          Alias = alias,
          Email = alias + '@example.com',
          Username = alias + '.' + uniqueSuffix + '@voicepoc.test',
          ProfileId = profileId,
          TimeZoneSidKey = 'America/Los_Angeles',
          LocaleSidKey = 'en_US',
          EmailEncodingKey = 'UTF-8',
          LanguageLocaleKey = 'en_US'
        )
      );
    }
    if (doInsert) {
      insert users;
    }
    return users;
  }

  /**
   * @param userIds users to receive the permission set
   * @param permissionSetName API name of the permission set
   * @return the assignments
   */
  public static List<PermissionSetAssignment> assignPermissionSet(
    List<Id> userIds,
    String permissionSetName
  ) {
    Id permissionSetId = [
      SELECT Id
      FROM PermissionSet
      WHERE Name = :permissionSetName
      LIMIT 1
    ]
    .Id;
    List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
    for (Id userId : userIds) {
      assignments.add(
        new PermissionSetAssignment(
          AssigneeId = userId,
          PermissionSetId = permissionSetId
        )
      );
    }
    insert assignments;
    return assignments;
  }
}
