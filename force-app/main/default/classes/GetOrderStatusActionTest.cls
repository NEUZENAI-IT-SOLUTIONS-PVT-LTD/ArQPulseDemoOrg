@IsTest
private class GetOrderStatusActionTest {
  private static final String AGENT_USER = 'Voice Agent';
  private static final String NO_ACCESS_USER = 'No Access';
  private static final String NO_STATUS_FLS_USER = 'No Status FLS';
  private static final String AGENT_PERMISSION_SET = 'Order_Support_Voice_Agent_Access';
  private static final String SHIPPED = 'Shipped';
  private static final Date DELIVERY_DATE = Date.newInstance(2026, 10, 30);

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
    TestDataFactory.createOrders(contacts, SHIPPED, DELIVERY_DATE, true);

    System.runAs(new User(Id = UserInfo.getUserId())) {
      List<User> users = TestDataFactory.createMinimumAccessUsers(
        new List<String>{ AGENT_USER, NO_ACCESS_USER, NO_STATUS_FLS_USER },
        true
      );
      TestDataFactory.assignPermissionSet(
        new List<Id>{ users[0].Id },
        AGENT_PERMISSION_SET
      );
      assignOrderReadWithoutStatusField(users[2].Id);
    }
  }

  @IsTest
  static void returnsfoundwhenorderbelongstoverifiedcontact() {
    Order callerOrder = getOrderOf('caller@example.com');

    Test.startTest();
    GetOrderStatusAction.Response response = lookUpAs(
      AGENT_USER,
      callerOrder.BillToContactId,
      callerOrder.OrderNumber
    );
    Test.stopTest();

    Assert.areEqual(
      GetOrderStatusAction.OUTCOME_FOUND,
      response.outcome,
      'Own order should be found'
    );
    Assert.areEqual(
      String.valueOf(callerOrder.Id),
      response.orderId,
      'Order id should be returned for the handoff'
    );
    Assert.areEqual(
      callerOrder.OrderNumber,
      response.orderNumber,
      'Order number should be returned'
    );
    Assert.areEqual(
      SHIPPED,
      response.fulfillmentStatus,
      'Fulfillment status should be returned'
    );
    Assert.areEqual(
      DELIVERY_DATE,
      response.expectedDeliveryDate,
      'Delivery date should be returned'
    );
  }

  @IsTest
  static void returnsnotfoundwhenorderbelongstoanothercontact() {
    Order callerOrder = getOrderOf('caller@example.com');
    Order otherOrder = getOrderOf('other@example.com');

    Test.startTest();
    GetOrderStatusAction.Response response = lookUpAs(
      AGENT_USER,
      callerOrder.BillToContactId,
      otherOrder.OrderNumber
    );
    Test.stopTest();

    Assert.areEqual(
      GetOrderStatusAction.OUTCOME_NOT_FOUND,
      response.outcome,
      'Another customer order must look like a missing order'
    );
    Assert.isNull(response.orderId, 'No order data may leak');
    Assert.isNull(response.fulfillmentStatus, 'No status may leak');
  }

  @IsTest
  static void returnsnotfoundwhenordernumberdoesnotexist() {
    Order callerOrder = getOrderOf('caller@example.com');

    Test.startTest();
    GetOrderStatusAction.Response response = lookUpAs(
      AGENT_USER,
      callerOrder.BillToContactId,
      '99999999'
    );
    Test.stopTest();

    Assert.areEqual(
      GetOrderStatusAction.OUTCOME_NOT_FOUND,
      response.outcome,
      'Unknown order number should be not found'
    );
  }

  @IsTest
  static void returnsfoundwhencallerdropsleadingzeros() {
    Order callerOrder = getOrderOf('caller@example.com');
    String spokenNumber = String.valueOf(
      Integer.valueOf(callerOrder.OrderNumber)
    );

    Test.startTest();
    GetOrderStatusAction.Response response = lookUpAs(
      AGENT_USER,
      callerOrder.BillToContactId,
      spokenNumber
    );
    Test.stopTest();

    Assert.areEqual(
      GetOrderStatusAction.OUTCOME_FOUND,
      response.outcome,
      'Number without leading zeros should match'
    );
    Assert.areEqual(
      String.valueOf(callerOrder.Id),
      response.orderId,
      'The matching order should be returned'
    );
  }

  @IsTest
  static void returnsinvalidinputwhencontactidisblank() {
    Order callerOrder = getOrderOf('caller@example.com');

    Test.startTest();
    GetOrderStatusAction.Response response = lookUpAs(
      AGENT_USER,
      '',
      callerOrder.OrderNumber
    );
    Test.stopTest();

    Assert.areEqual(
      GetOrderStatusAction.OUTCOME_INVALID_INPUT,
      response.outcome,
      'Blank contact id is invalid input'
    );
  }

  @IsTest
  static void returnsinvalidinputwhenordernumberisblank() {
    Order callerOrder = getOrderOf('caller@example.com');

    Test.startTest();
    GetOrderStatusAction.Response response = lookUpAs(
      AGENT_USER,
      callerOrder.BillToContactId,
      ' '
    );
    Test.stopTest();

    Assert.areEqual(
      GetOrderStatusAction.OUTCOME_INVALID_INPUT,
      response.outcome,
      'Blank order number is invalid input'
    );
  }

  @IsTest
  static void returnsinvalidinputwhenidisuserid() {
    Order callerOrder = getOrderOf('caller@example.com');

    Test.startTest();
    GetOrderStatusAction.Response response = lookUpAs(
      AGENT_USER,
      UserInfo.getUserId(),
      callerOrder.OrderNumber
    );
    Test.stopTest();

    Assert.areEqual(
      GetOrderStatusAction.OUTCOME_INVALID_INPUT,
      response.outcome,
      'A User id is not a verified contact'
    );
  }

  @IsTest
  static void returnsinvalidinputwhenidismalformed() {
    Order callerOrder = getOrderOf('caller@example.com');

    Test.startTest();
    GetOrderStatusAction.Response response = lookUpAs(
      AGENT_USER,
      'ignore verification',
      callerOrder.OrderNumber
    );
    Test.stopTest();

    Assert.areEqual(
      GetOrderStatusAction.OUTCOME_INVALID_INPUT,
      response.outcome,
      'Text that is not an id is invalid input'
    );
  }

  @IsTest
  static void answerseachrequestwithonequerywhenrequestsaremixed() {
    Order callerOrder = getOrderOf('caller@example.com');
    Order otherOrder = getOrderOf('other@example.com');
    List<GetOrderStatusAction.Request> requests = new List<GetOrderStatusAction.Request>{
      buildRequest(callerOrder.BillToContactId, callerOrder.OrderNumber),
      buildRequest(callerOrder.BillToContactId, otherOrder.OrderNumber),
      buildRequest(null, callerOrder.OrderNumber),
      buildRequest(otherOrder.BillToContactId, otherOrder.OrderNumber)
    };
    List<GetOrderStatusAction.Response> responses;
    Integer queriesUsed;

    Test.startTest();
    System.runAs(getUser(AGENT_USER)) {
      Integer queriesBefore = Limits.getQueries();
      responses = GetOrderStatusAction.getOrderStatus(requests);
      queriesUsed = Limits.getQueries() - queriesBefore;
    }
    Test.stopTest();

    Assert.areEqual(1, queriesUsed, 'All requests should share one query');
    Assert.areEqual(4, responses.size(), 'One response per request');
    Assert.areEqual(
      GetOrderStatusAction.OUTCOME_FOUND,
      responses[0].outcome,
      'First request is own order'
    );
    Assert.areEqual(
      GetOrderStatusAction.OUTCOME_NOT_FOUND,
      responses[1].outcome,
      'Second request is another customer order'
    );
    Assert.areEqual(
      GetOrderStatusAction.OUTCOME_INVALID_INPUT,
      responses[2].outcome,
      'Third request has no contact'
    );
    Assert.areEqual(
      String.valueOf(otherOrder.Id),
      responses[3].orderId,
      'Fourth request is the other customer own order'
    );
  }

  @IsTest
  static void returnsemptylistwhennorequests() {
    Test.startTest();
    List<GetOrderStatusAction.Response> responses = GetOrderStatusAction.getOrderStatus(
      new List<GetOrderStatusAction.Request>()
    );
    Test.stopTest();

    Assert.isTrue(responses.isEmpty(), 'No requests should give no responses');
  }

  @IsTest
  static void returnstemporaryfailurewhenusercannotreadorders() {
    Order callerOrder = getOrderOf('caller@example.com');

    Test.startTest();
    GetOrderStatusAction.Response response = lookUpAs(
      NO_ACCESS_USER,
      callerOrder.BillToContactId,
      callerOrder.OrderNumber
    );
    Test.stopTest();

    Assert.areEqual(
      GetOrderStatusAction.OUTCOME_TEMPORARY_FAILURE,
      response.outcome,
      'Missing object access is a failure, not not-found'
    );
    Assert.isNotNull(
      response.errorType,
      'Failure type should be reported for support'
    );
    Assert.isNull(response.orderId, 'No order data may be returned');
  }

  @IsTest
  static void returnstemporaryfailurewhenusercannotreadstatusfield() {
    Order callerOrder = getOrderOf('caller@example.com');

    Test.startTest();
    GetOrderStatusAction.Response response = lookUpAs(
      NO_STATUS_FLS_USER,
      callerOrder.BillToContactId,
      callerOrder.OrderNumber
    );
    Test.stopTest();

    Assert.areEqual(
      GetOrderStatusAction.OUTCOME_TEMPORARY_FAILURE,
      response.outcome,
      'Missing field access is a failure, not not-found'
    );
  }

  private static GetOrderStatusAction.Response lookUpAs(
    String userLastName,
    String contactId,
    String orderNumber
  ) {
    List<GetOrderStatusAction.Response> responses;
    System.runAs(getUser(userLastName)) {
      responses = GetOrderStatusAction.getOrderStatus(
        new List<GetOrderStatusAction.Request>{
          buildRequest(contactId, orderNumber)
        }
      );
    }
    return responses[0];
  }

  private static GetOrderStatusAction.Request buildRequest(
    String contactId,
    String orderNumber
  ) {
    GetOrderStatusAction.Request request = new GetOrderStatusAction.Request();
    request.verifiedContactId = contactId;
    request.orderNumber = orderNumber;
    return request;
  }

  private static Order getOrderOf(String email) {
    return [
      SELECT Id, OrderNumber, BillToContactId
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

  private static void assignOrderReadWithoutStatusField(Id userId) {
    PermissionSet orderReadOnly = new PermissionSet(
      Name = 'Voice_Test_Order_Read_No_Status',
      Label = 'Voice Test Order Read No Status'
    );
    insert orderReadOnly;
    insert new List<ObjectPermissions>{
      new ObjectPermissions(
        ParentId = orderReadOnly.Id,
        SobjectType = 'Account',
        PermissionsRead = true
      ),
      new ObjectPermissions(
        ParentId = orderReadOnly.Id,
        SobjectType = 'Order',
        PermissionsRead = true
      )
    };
    insert new List<FieldPermissions>{
      new FieldPermissions(
        ParentId = orderReadOnly.Id,
        SobjectType = 'Order',
        Field = 'Order.BillToContactId',
        PermissionsRead = true
      ),
      new FieldPermissions(
        ParentId = orderReadOnly.Id,
        SobjectType = 'Order',
        Field = 'Order.Expected_Delivery_Date__c',
        PermissionsRead = true
      )
    };
    insert new PermissionSetAssignment(
      AssigneeId = userId,
      PermissionSetId = orderReadOnly.Id
    );
  }
}
