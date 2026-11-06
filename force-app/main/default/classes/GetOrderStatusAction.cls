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
    List<Response> responses = new List<Response>();
    if (requests == null || requests.isEmpty()) {
      return responses;
    }

    Set<Id> contactIds = new Set<Id>();
    Set<String> orderNumbers = new Set<String>();
    List<String> keys = new List<String>();
    for (Request request : requests) {
      Id contactId = toContactId(request?.verifiedContactId);
      String orderNumber = normalizeOrderNumber(request?.orderNumber);
      if (contactId == null || orderNumber == null) {
        keys.add(null);
        continue;
      }
      contactIds.add(contactId);
      orderNumbers.add(orderNumber);
      keys.add(buildKey(contactId, orderNumber));
    }

    Map<String, Order> ordersByKey;
    try {
      ordersByKey = getOrdersByKey(contactIds, orderNumbers);
    } catch (Exception queryError) {
      // Access or platform failure: the agent must offer recovery, not say "not found".
      for (String key : keys) {
        responses.add(
          key == null
            ? new Response(OUTCOME_INVALID_INPUT)
            : new Response(OUTCOME_TEMPORARY_FAILURE, queryError.getTypeName())
        );
      }
      return responses;
    }

    for (String key : keys) {
      if (key == null) {
        responses.add(new Response(OUTCOME_INVALID_INPUT));
      } else if (ordersByKey.containsKey(key)) {
        responses.add(new Response(ordersByKey.get(key)));
      } else {
        // Same answer for a missing order and someone else's order.
        responses.add(new Response(OUTCOME_NOT_FOUND));
      }
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

  private static Id toContactId(String value) {
    if (String.isBlank(value)) {
      return null;
    }
    try {
      Id candidate = Id.valueOf(value.trim());
      return candidate.getSObjectType() == Contact.SObjectType
        ? candidate
        : null;
    } catch (StringException invalidId) {
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
