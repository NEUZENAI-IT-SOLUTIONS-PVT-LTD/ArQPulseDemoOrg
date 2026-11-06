/**
 * Agent action that returns the status of one order for a verified customer.
 *
 * Trust boundary: this class does not authenticate the caller. The agent passes
 * the contact id that its verification step stored; this class only returns an
 * order when that contact is the order's bill-to contact. `with sharing` and
 * `USER_MODE` enforce the agent user's Salesforce access, nothing more.
 */
public with sharing class GetOrderStatusAction {
  public static final String OUTCOME_FOUND = 'FOUND';
  public static final String OUTCOME_NOT_FOUND = 'NOT_FOUND';
  public static final String OUTCOME_INVALID_INPUT = 'INVALID_INPUT';
  public static final String OUTCOME_TEMPORARY_FAILURE = 'TEMPORARY_FAILURE';

  private static final Integer MAX_ROWS = 2000;
  // Order numbers in this org are 8-digit auto numbers; callers often drop the leading zeros.
  private static final Integer ORDER_NUMBER_LENGTH = 8;
  private static final String KEY_SEPARATOR = ':';

  /**
   * Looks up each requested order, limited to orders billed to the verified contact.
   * @param requests verified contact id and order number per request
   * @return one response per request, in the same order
   */
  @InvocableMethod(
    label='Get Order Status for Verified Customer'
    description='Returns the fulfillment status and expected delivery date of an order that belongs to the verified customer.'
    category='Order Support'
  )
  public static List<Response> getOrderStatus(List<Request> requests) {
    if (requests == null || requests.isEmpty()) {
      return new List<Response>();
    }
    return doGetOrderStatus(requests);
  }

  private class LookupData {
    public List<String> keys;
    public Set<Id> contactIds;
    public Set<String> orderNumbers;
    public LookupData() {
      this.keys = new List<String>();
      this.contactIds = new Set<Id>();
      this.orderNumbers = new Set<String>();
    }
  }

  private static List<Response> doGetOrderStatus(List<Request> requests) {
    LookupData data = buildLookupSets(requests);
    return performLookupAndBuildResponses(data);
  }

  private static List<Response> performLookupAndBuildResponses(
    LookupData data
  ) {
    try {
      Map<String, Order> ordersByKey = getOrdersByKey(
        data.contactIds,
        data.orderNumbers
      );
      return buildResponsesForKeys(ordersByKey, data.keys);
    } catch (Exception queryError) {
      return buildResponsesForAllKeysOnQueryError(data.keys, queryError);
    }
  }

  private static LookupData buildLookupSets(List<Request> requests) {
    LookupData data = new LookupData();
    for (Request request : requests) {
      Id contactId = toContactId(request?.verifiedContactId);
      String orderNumber = normalizeOrderNumber(request?.orderNumber);
      if (contactId == null || orderNumber == null) {
        data.keys.add(null);
        continue;
      }
      data.contactIds.add(contactId);
      data.orderNumbers.add(orderNumber);
      data.keys.add(buildKey(contactId, orderNumber));
    }
    return data;
  }

  private static List<Response> buildResponsesForKeys(
    Map<String, Order> ordersByKey,
    List<String> keys
  ) {
    List<Response> responses = new List<Response>();
    for (String key : keys) {
      responses.add(buildResponseForKey(ordersByKey, key));
    }
    return responses;
  }

  private static Map<String, Order> getOrdersByKey(
    Set<Id> contactIds,
    Set<String> orderNumbers
  ) {
    Map<String, Order> ordersByKey = new Map<String, Order>();
    if (contactIds.isEmpty()) {
      return ordersByKey;
    }
    for (Order matchingOrder : [
      SELECT
        Id,
        OrderNumber,
        BillToContactId,
        Fulfillment_Status__c,
        Expected_Delivery_Date__c
      FROM Order
      WHERE BillToContactId IN :contactIds AND OrderNumber IN :orderNumbers
      WITH USER_MODE
      ORDER BY OrderNumber ASC NULLS LAST, Id
      LIMIT :MAX_ROWS
    ]) {
      ordersByKey.put(
        buildKey(matchingOrder.BillToContactId, matchingOrder.OrderNumber),
        matchingOrder
      );
    }
    return ordersByKey;
  }
  private static List<Response> buildResponsesForAllKeysOnQueryError(
    List<String> keys,
    Exception queryError
  ) {
    List<Response> responses = new List<Response>();
    for (String key : keys) {
      responses.add(
        key == null
          ? new Response(OUTCOME_INVALID_INPUT)
          : new Response(OUTCOME_TEMPORARY_FAILURE, queryError.getTypeName())
      );
    }
    return responses;
  }

  private static Response buildResponseForKey(
    Map<String, Order> ordersByKey,
    String key
  ) {
    if (key == null) {
      return new Response(OUTCOME_INVALID_INPUT);
    }
    if (ordersByKey.containsKey(key)) {
      return new Response(ordersByKey.get(key));
    }
    return new Response(OUTCOME_NOT_FOUND);
  }

  private static Id toContactId(String value) {
    if (String.isBlank(value)) {
      return null;
    }
    try {
      Id candidate = Id.valueOf(value.trim());
      return candidate.getSObjectType() == Contact.SObjectType
        ? candidate
        : null;
    } catch (Exception invalidId) {
      return null;
    }
  }

  private static String normalizeOrderNumber(String value) {
    if (String.isBlank(value)) {
      return null;
    }
    String trimmed = value.deleteWhitespace();
    if (trimmed.isNumeric() && trimmed.length() < ORDER_NUMBER_LENGTH) {
      return trimmed.leftPad(ORDER_NUMBER_LENGTH, '0');
    }
    return trimmed;
  }

  private static String buildKey(Id contactId, String orderNumber) {
    return String.valueOf(contactId) + KEY_SEPARATOR + orderNumber;
  }

  /**
   * Input from the agent.
   */
  public class Request {
    @InvocableVariable(
      label='Verified Contact Id'
      description='Contact id stored by the verification step. Never taken from what the caller says.'
      required=true
    )
    public String verifiedContactId;

    @InvocableVariable(
      label='Order Number'
      description='Order number the caller says, for example 00000100 or 100.'
      required=true
    )
    public String orderNumber;
  }

  /**
   * Result for the agent.
   */
  public class Response {
    @InvocableVariable(
      label='Outcome'
      description='FOUND, NOT_FOUND, INVALID_INPUT or TEMPORARY_FAILURE.'
    )
    public String outcome;

    @InvocableVariable(
      label='Order Id'
      description='Id of the found order, for the handoff case.'
    )
    public String orderId;

    @InvocableVariable(
      label='Order Number'
      description='Order number of the found order.'
    )
    public String orderNumber;

    @InvocableVariable(
      label='Fulfillment Status'
      description='Shipping stage of the found order.'
    )
    public String fulfillmentStatus;

    @InvocableVariable(
      label='Expected Delivery Date'
      description='Expected delivery date of the found order.'
    )
    public Date expectedDeliveryDate;

    @InvocableVariable(
      label='Error Type'
      description='Exception type on TEMPORARY_FAILURE, for support logs. Not for the caller.'
    )
    public String errorType;

    public Response(String outcome) {
      this.outcome = outcome;
    }

    public Response(String outcome, String errorType) {
      this.outcome = outcome;
      this.errorType = errorType;
    }

    public Response(Order foundOrder) {
      this.outcome = OUTCOME_FOUND;
      this.orderId = foundOrder.Id;
      this.orderNumber = foundOrder.OrderNumber;
      this.fulfillmentStatus = foundOrder.Fulfillment_Status__c;
      this.expectedDeliveryDate = foundOrder.Expected_Delivery_Date__c;
    }
  }
}
