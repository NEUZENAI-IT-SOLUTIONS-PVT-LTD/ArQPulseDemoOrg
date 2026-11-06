@IsTest
private class CreateHandoffCaseActionTest {
  private static final String AGENT_USER = 'Voice Agent';
  private static final String NO_ACCESS_USER = 'No Access';
  private static final String AGENT_PERMISSION_SET = 'Order_Support_Voice_Agent_Access';
  private static final String SESSION_KEY = '0LQTESTVOICECALL01';
  private static final String INTENT = 'Order status';
  private static final String SUMMARY = 'Caller asked where order is; verified; order shipped.';
  private static final String STATED = 'Caller said order 100.';

  @TestSetup
  static void setupData() {
    List<Account> accounts = TestDataFactory.createAccounts(
      new List<String>{ 'Caller Household', 'Other Household' },
      true
    );
    List<Contact> contacts = TestDataFactory.createContacts(
      accounts,
      new List<String>{ 'caller@example.com', 'other@example.com' },
      true
    );
    TestDataFactory.createOrders(
      contacts,
      'Shipped',
      Date.today().addDays(1),
      true
    );

    System.runAs(new User(Id = UserInfo.getUserId())) {
      List<User> users = TestDataFactory.createMinimumAccessUsers(
        new List<String>{ AGENT_USER, NO_ACCESS_USER },
        true
      );
      TestDataFactory.assignPermissionSet(
        new List<Id>{ users[0].Id },
        AGENT_PERMISSION_SET
      );
    }
  }

  @IsTest
  static void createsCaseWhenCallerIsVerifiedWithOwnOrder() {
    Order callerOrder = getOrderOf('caller@example.com');

    Test.startTest();
    CreateHandoffCaseAction.Response response = handOffAs(
      AGENT_USER,
      buildRequest(
        SESSION_KEY,
        true,
        callerOrder.BillToContactId + '|' + callerOrder.Id
      )
    );
    Test.stopTest();

    Case handoff = getCase(response.caseId);
    Assert.areEqual(
      CreateHandoffCaseAction.OUTCOME_CREATED,
      response.outcome,
      'A new case should be created'
    );
    Assert.areEqual(
      callerOrder.BillToContactId,
      handoff.ContactId,
      'Verified contact should be linked'
    );
    Assert.isTrue(
      handoff.Is_Identity_Verified__c,
      'Verified flag should be set'
    );
    Assert.areEqual(
      callerOrder.Id,
      handoff.Related_Order__c,
      'Own order should be linked'
    );
    Assert.areEqual('Phone', handoff.Origin, 'Origin should be Phone');
    Assert.areEqual(
      INTENT,
      handoff.Caller_Intent__c,
      'Intent should be stored'
    );
    Assert.areEqual(
      SUMMARY,
      handoff.AI_Generated_Call_Summary__c,
      'AI summary should be stored'
    );
    Assert.areEqual(
      STATED,
      handoff.Caller_Stated_Details__c,
      'Stated details should be stored apart'
    );
    Assert.areEqual(
      SESSION_KEY,
      handoff.Agent_Session_Key__c,
      'Session key should be stored'
    );
  }

  @IsTest
  static void returnsExistingCaseUnchangedWhenRetried() {
    Order callerOrder = getOrderOf('caller@example.com');
    CreateHandoffCaseAction.Request first = buildRequest(
      SESSION_KEY,
      true,
      callerOrder.BillToContactId + '|' + callerOrder.Id
    );
    CreateHandoffCaseAction.Request retry = buildRequest(
      SESSION_KEY,
      true,
      callerOrder.BillToContactId + '|' + callerOrder.Id
    );
    retry.aiSummary = 'A different summary on retry';

    Test.startTest();
    CreateHandoffCaseAction.Response created = handOffAs(AGENT_USER, first);
    CreateHandoffCaseAction.Response retried = handOffAs(AGENT_USER, retry);
    Test.stopTest();

    Assert.areEqual(
      CreateHandoffCaseAction.OUTCOME_EXISTING,
      retried.outcome,
      'Retry should return the existing case'
    );
    Assert.areEqual(
      created.caseId,
      retried.caseId,
      'Retry should return the same case id'
    );
    Assert.areEqual(
      SUMMARY,
      getCase(created.caseId).AI_Generated_Call_Summary__c,
      'Retry must not change the case'
    );
    Assert.areEqual(1, countCases(SESSION_KEY), 'Only one case per session');
  }

  @IsTest
  static void createsOneCaseWhenSameKeyAppearsTwiceInOneCall() {
    Order callerOrder = getOrderOf('caller@example.com');
    List<CreateHandoffCaseAction.Response> responses;

    Test.startTest();
    System.runAs(getUser(AGENT_USER)) {
      responses = CreateHandoffCaseAction.createHandoffCases(
        new List<CreateHandoffCaseAction.Request>{
          buildRequest(
            SESSION_KEY,
            true,
            callerOrder.BillToContactId + '|' + callerOrder.Id
          ),
          buildRequest(
            SESSION_KEY,
            true,
            callerOrder.BillToContactId + '|' + callerOrder.Id
          )
        }
      );
    }
    Test.stopTest();

    Assert.areEqual(
      CreateHandoffCaseAction.OUTCOME_CREATED,
      responses[0].outcome,
      'First request creates the case'
    );
    Assert.areEqual(
      CreateHandoffCaseAction.OUTCOME_EXISTING,
      responses[1].outcome,
      'Second request reuses it'
    );
    Assert.areEqual(
      responses[0].caseId,
      responses[1].caseId,
      'Both requests point at one case'
    );
    Assert.areEqual(1, countCases(SESSION_KEY), 'Only one case per session');
  }

  @IsTest
  static void returnsExistingWhenAnotherCallCreatedTheCaseFirst() {
    Order callerOrder = getOrderOf('caller@example.com');
    Case otherCallCase = new Case(
      Subject = 'Created by a concurrent call',
      Agent_Session_Key__c = SESSION_KEY
    );
    insert otherCallCase;
    CreateHandoffCaseAction.isFirstReadSkipped = true;

    Test.startTest();
    CreateHandoffCaseAction.Response response = handOffAs(
      AGENT_USER,
      buildRequest(
        SESSION_KEY,
        true,
        callerOrder.BillToContactId + '|' + callerOrder.Id
      )
    );
    Test.stopTest();

    Assert.areEqual(
      CreateHandoffCaseAction.OUTCOME_EXISTING,
      response.outcome,
      'Duplicate key should resolve to the existing case'
    );
    Assert.areEqual(
      String.valueOf(otherCallCase.Id),
      response.caseId,
      'The case created first should be returned'
    );
    Assert.areEqual(
      1,
      countCases(SESSION_KEY),
      'No second case may be created'
    );
  }

  @IsTest
  static void createsNothingWhenSessionKeyIsMissing() {
    Order callerOrder = getOrderOf('caller@example.com');

    Test.startTest();
    CreateHandoffCaseAction.Response response = handOffAs(
      AGENT_USER,
      buildRequest(
        ' ',
        true,
        callerOrder.BillToContactId + '|' + callerOrder.Id
      )
    );
    Test.stopTest();

    Assert.areEqual(
      CreateHandoffCaseAction.OUTCOME_MISSING_SESSION_KEY,
      response.outcome,
      'Missing key must be rejected'
    );
    Assert.isNull(response.caseId, 'No case id without a key');
    Assert.areEqual(0, [SELECT COUNT() FROM Case], 'No case may be created');
  }

  @IsTest
  static void linksNoContactWhenCallerIsNotVerified() {
    Order callerOrder = getOrderOf('caller@example.com');

    Test.startTest();
    CreateHandoffCaseAction.Response response = handOffAs(
      AGENT_USER,
      buildRequest(
        SESSION_KEY,
        false,
        callerOrder.BillToContactId + '|' + callerOrder.Id
      )
    );
    Test.stopTest();

    Case handoff = getCase(response.caseId);
    Assert.areEqual(
      CreateHandoffCaseAction.OUTCOME_CREATED,
      response.outcome,
      'Unverified callers still get a handoff case'
    );
    Assert.isNull(
      handoff.ContactId,
      'Unverified caller must not be linked to a contact'
    );
    Assert.isFalse(
      handoff.Is_Identity_Verified__c,
      'Verified flag must be false'
    );
    Assert.isNull(
      handoff.Related_Order__c,
      'No order for an unverified caller'
    );
  }

  @IsTest
  static void linksNoContactWhenVerifiedIdIsNotAContact() {
    Test.startTest();
    CreateHandoffCaseAction.Response response = handOffAs(
      AGENT_USER,
      buildRequest(SESSION_KEY, true, UserInfo.getUserId() + '|')
    );
    Test.stopTest();

    Case handoff = getCase(response.caseId);
    Assert.isNull(
      handoff.ContactId,
      'A User id must not be linked as a contact'
    );
    Assert.isFalse(
      handoff.Is_Identity_Verified__c,
      'Verified flag needs a contact'
    );
  }

  @IsTest
  static void linksNoOrderWhenOrderBelongsToAnotherContact() {
    Order callerOrder = getOrderOf('caller@example.com');
    Order otherOrder = getOrderOf('other@example.com');

    Test.startTest();
    CreateHandoffCaseAction.Response response = handOffAs(
      AGENT_USER,
      buildRequest(
        SESSION_KEY,
        true,
        callerOrder.BillToContactId + '|' + otherOrder.Id
      )
    );
    Test.stopTest();

    Case handoff = getCase(response.caseId);
    Assert.areEqual(
      callerOrder.BillToContactId,
      handoff.ContactId,
      'Verified contact is still linked'
    );
    Assert.isNull(
      handoff.Related_Order__c,
      'Another customer order must not be linked'
    );
  }

  @IsTest
  static void returnsFailedWhenUserCannotAccessCases() {
    Order callerOrder = getOrderOf('caller@example.com');

    Test.startTest();
    CreateHandoffCaseAction.Response response = handOffAs(
      NO_ACCESS_USER,
      buildRequest(
        SESSION_KEY,
        true,
        callerOrder.BillToContactId + '|' + callerOrder.Id
      )
    );
    Test.stopTest();

    Assert.areEqual(
      CreateHandoffCaseAction.OUTCOME_FAILED,
      response.outcome,
      'No Case access should fail, not throw'
    );
    Assert.isNotNull(
      response.errorType,
      'Failure type should be reported for support'
    );
    Assert.areEqual(0, countCases(SESSION_KEY), 'No case may be created');
  }

  @IsTest
  static void returnsEmptyListWhenNoRequests() {
    Test.startTest();
    List<CreateHandoffCaseAction.Response> responses = CreateHandoffCaseAction.createHandoffCases(
      new List<CreateHandoffCaseAction.Request>()
    );
    Test.stopTest();

    Assert.isTrue(responses.isEmpty(), 'No requests should give no responses');
  }

  private static CreateHandoffCaseAction.Response handOffAs(
    String userLastName,
    CreateHandoffCaseAction.Request request
  ) {
    List<CreateHandoffCaseAction.Response> responses;
    System.runAs(getUser(userLastName)) {
      responses = CreateHandoffCaseAction.createHandoffCases(
        new List<CreateHandoffCaseAction.Request>{ request }
      );
    }
    return responses[0];
  }

  private static CreateHandoffCaseAction.Request buildRequest(
    String sessionKey,
    Boolean isVerified,
    String contactAndOrder
  ) {
    // NOPMD
    CreateHandoffCaseAction.Request request = new CreateHandoffCaseAction.Request();
    request.sessionKey = sessionKey;
    request.isVerified = isVerified;
    if (contactAndOrder != null) {
      List<String> parts = contactAndOrder.split('\\|', 2);
      request.verifiedContactId = (parts.size() > 0 &&
        parts[0] != '')
        ? parts[0]
        : null;
      request.orderId = (parts.size() > 1 && parts[1] != '') ? parts[1] : null;
    } else {
      request.verifiedContactId = null;
      request.orderId = null;
    }
    request.callerIntent = INTENT;
    request.aiSummary = SUMMARY;
    request.callerStatedDetails = STATED;
    return request;
  }

  private static Case getCase(Id caseId) {
    return [
      SELECT
        ContactId,
        Is_Identity_Verified__c,
        Related_Order__c,
        Origin,
        Caller_Intent__c,
        AI_Generated_Call_Summary__c,
        Caller_Stated_Details__c,
        Agent_Session_Key__c
      FROM Case
      WHERE Id = :caseId
    ];
  }

  private static Integer countCases(String sessionKey) {
    return [SELECT COUNT() FROM Case WHERE Agent_Session_Key__c = :sessionKey];
  }

  private static Order getOrderOf(String email) {
    return [
      SELECT Id, BillToContactId
      FROM Order
      WHERE BillToContact.Email = :email
      LIMIT 1
    ];
  }

  private static User getUser(String lastName) {
    return [
      SELECT Id
      FROM User
      WHERE LastName = :lastName AND Email LIKE '%@example.com'
      LIMIT 1
    ];
  }
}
