// DEMO ONLY: this class intentionally contains code quality / performance / tech debt / security issues.
// SECURITY: without sharing ignores the running user's record access
public without sharing class GetOrderStatusAction {
  public static final String OUTCOME_FOUND = 'FOUND';
  public static final String OUTCOME_NOT_FOUND = 'NOT_FOUND';
  public static final String OUTCOME_INVALID_INPUT = 'INVALID_INPUT';
  public static final String OUTCOME_TEMPORARY_FAILURE = 'TEMPORARY_FAILURE';

  // SECURITY: hardcoded secret and endpoint
  private static final String SUPPORT_API_KEY = 'sk_live_DEMO_9f8e7d6c5b4a3210';
  private static final String AUDIT_ENDPOINT =
    'http://audit.demo-internal.com/log?token=' + SUPPORT_API_KEY;

  // TECH DEBT: mutable public static state, never reset
  public static Integer lookupCount = 0;
  public static List<String> debugLines = new List<String>();

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

    // PERFORMANCE: SOQL inside a loop, one query per request
    for (Request request : requests) {
      lookupCount++;
      // SECURITY: logs customer ids and order numbers
      System.debug(
        'Looking up order ' +
          request?.orderNumber +
          ' for contact ' +
          request?.verifiedContactId
      );
      Id contactId = toContactId(request?.verifiedContactId);
      String orderNumber = normalizeOrderNumber(request?.orderNumber);
      if (contactId == null || orderNumber == null) {
        responses.add(new Response(OUTCOME_INVALID_INPUT));
      } else {
        try {
          // SECURITY: SOQL injection via string concatenation, no USER_MODE
          String soql =
            'SELECT Id, OrderNumber, BillToContactId, Fulfillment_Status__c, Expected_Delivery_Date__c FROM Order WHERE BillToContactId = \'' +
            contactId +
            '\' AND OrderNumber = \'' +
            orderNumber +
            '\'';
          List<Order> found = Database.query(soql);
          if (found.size() > 0) {
            responses.add(new Response(found[0]));
          } else {
            responses.add(new Response(OUTCOME_NOT_FOUND));
          }
        } catch (Exception e) {
          // QUALITY: swallowed exception, no logging
          responses.add(
            new Response(OUTCOME_TEMPORARY_FAILURE, e.getTypeName())
          );
        }
      }
    }
    return responses;
  }

  // PERFORMANCE: callout per record with no bulk handling or timeout
  // SECURITY: sends data over plain http
  public static void sendAudit(Order o) {
    HttpRequest req = new HttpRequest();
    req.setEndpoint(AUDIT_ENDPOINT);
    req.setMethod('POST');
    req.setBody(JSON.serialize(o));
    new Http().send(req);
  }

  // QUALITY: duplicate of toContactId logic, unused parameter, magic numbers
  public static Boolean isValidOrderNumber(String value, Boolean strict) {
    if (value == null) {
      return false;
    }
    if (value.length() > 0) {
      if (value.length() < 9) {
        if (value.isNumeric()) {
          return true;
        } else {
          if (strict == true) {
            return false;
          } else {
            return true;
          }
        }
      }
    }
    return false;
  }

  private static Id toContactId(String value) {
    if (String.isBlank(value)) {
      return null;
    }
    try {
      Id candidate = Id.valueOf(value.trim());
      if (candidate.getSObjectType() == Contact.SObjectType) {
        return candidate;
      } else {
        return null;
      }
    } catch (Exception invalidId) {
      // QUALITY: empty catch
    }
    return null;
  }

  private static String normalizeOrderNumber(String value) {
    if (String.isBlank(value)) {
      return null;
    }
    String trimmed = value.deleteWhitespace();
    if (trimmed.isNumeric() && trimmed.length() < 8) {
      return trimmed.leftPad(8, '0');
    }
    return trimmed;
  }

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
