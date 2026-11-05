/**
 * Agent action that creates one handoff case per call before a transfer to a person.
 *
 * Idempotent by session key: a retry or a concurrent call with the same key returns
 * the existing case and never updates it, so the action needs Read + Create on Case
 * and no Edit. The contact and order are linked only when the agent's protected
 * state says the caller was verified and the order belongs to that contact.
 */
public with sharing class CreateHandoffCaseAction {
  public static final String OUTCOME_CREATED = 'CREATED';
  public static final String OUTCOME_EXISTING = 'EXISTING';
  public static final String OUTCOME_MISSING_SESSION_KEY = 'MISSING_SESSION_KEY';
  public static final String OUTCOME_FAILED = 'FAILED';

  private static final String CASE_ORIGIN = 'Phone';
  private static final String SUBJECT_PREFIX = 'Voice handoff: ';
  private static final String DEFAULT_INTENT = 'Caller asked for a person';
  private static final Integer SHORT_TEXT_LENGTH = 255;
  private static final Integer LONG_TEXT_LENGTH = 32768;
  private static final Integer MAX_ROWS = 2000;

  // Lets a test simulate another call committing its case between our read and our insert.
  @TestVisible
  private static Boolean isFirstReadSkipped = false;

  private class ProcessingInput {
    public Set<String> sessionKeys;
    public Set<Id> verifiedContactIds;
    public Set<Id> orderIds;
    public ProcessingInput(
      Set<String> sessionKeys,
      Set<Id> verifiedContactIds,
      Set<Id> orderIds
    ) {
      this.sessionKeys = sessionKeys;
      this.verifiedContactIds = verifiedContactIds;
      this.orderIds = orderIds;
    }
  }
  /**
   * Creates or returns the handoff case for each session.
   * @param requests session key, verified state and handoff context per request
   * @return one response per request, in the same order
   */
  @InvocableMethod(
    label='Create Voice Handoff Case'
    description='Creates one case per call with the verified customer, order, intent and AI summary for the receiving rep. Returns the existing case on retry.'
    category='Order Support'
  )
  public static List<Response> createHandoffCases(List<Request> requests) {
    // NOPMD
    if (requests == null || requests.isEmpty()) {
      return new List<Response>();
    }
    return createHandoffCasesInternal(requests);
  }

  private static List<Response> createHandoffCasesInternal(
    List<Request> requests
  ) {
    Set<String> sessionKeys = new Set<String>();
    Set<Id> verifiedContactIds = new Set<Id>();
    Set<Id> orderIds = new Set<Id>();
    ProcessingInput input = new ProcessingInput(
      sessionKeys,
      verifiedContactIds,
      orderIds
    );
    collectSessionAndIds(requests, input);

    return handleProcessing(requests, input);
  }

  private static List<Response> handleProcessing(
    List<Request> requests,
    ProcessingInput input
  ) {
    try {
      return processRequests(requests, input);
    } catch (Exception handoffError) {
      List<Response> responses = new List<Response>();
      for (Request request : requests) {
        responses.add(
          String.isBlank(request?.sessionKey)
            ? new Response(OUTCOME_MISSING_SESSION_KEY, null)
            : new Response(OUTCOME_FAILED, null, handoffError.getTypeName())
        );
      }
      return responses;
    }
  }
  private static List<Response> processRequests(
    List<Request> requests,
    ProcessingInput input
  ) {
    Map<String, Id> caseIdsByKey = isFirstReadSkipped
      ? new Map<String, Id>()
      : getCaseIdsByKey(input.sessionKeys);
    Map<Id, Id> contactIdsByOrderId = getBillToContactIdsByOrderId(
      input.orderIds,
      input.verifiedContactIds
    );

    Map<String, Case> newCasesByKey = buildNewCasesMap(
      requests,
      caseIdsByKey,
      contactIdsByOrderId
    );

    Map<String, String> failuresByKey = insertCases(newCasesByKey);
    if (!failuresByKey.isEmpty()) {
      // A concurrent call may have created the case first; read the winners.
      caseIdsByKey.putAll(getCaseIdsByKey(failuresByKey.keySet()));
    }

    ResponseContext ctx = new ResponseContext(
      new Map<String, Object>{
        'caseIdsByKey' => caseIdsByKey,
        'newCasesByKey' => newCasesByKey,
        'failuresByKey' => failuresByKey
      }
    );
    return buildResponsesList(requests, ctx);
  }

  private static void collectSessionAndIds(
    List<Request> requests,
    ProcessingInput input
  ) {
    for (Request request : requests) {
      if (String.isBlank(request?.sessionKey)) {
        continue;
      }
      input.sessionKeys.add(request.sessionKey.trim());
      Id contactId = getVerifiedContactId(request);
      Id orderId = toIdOfType(request.orderId, Order.SObjectType);
      if (contactId != null && orderId != null) {
        input.verifiedContactIds.add(contactId);
        input.orderIds.add(orderId);
      }
    }
  }

  private static Map<String, Case> buildNewCasesMap(
    List<Request> requests,
    Map<String, Id> caseIdsByKey,
    Map<Id, Id> contactIdsByOrderId
  ) {
    Map<String, Case> newCasesByKey = new Map<String, Case>();
    for (Request request : requests) {
      String key = request?.sessionKey?.trim();
      if (
        String.isNotBlank(key) &&
        !caseIdsByKey.containsKey(key) &&
        !newCasesByKey.containsKey(key)
      ) {
        newCasesByKey.put(key, buildCase(request, key, contactIdsByOrderId));
      }
    }
    return newCasesByKey;
  }

  private static List<Response> buildResponsesList(
    List<Request> requests,
    ResponseContext ctx
  ) {
    List<Response> responses = new List<Response>();
    for (Request request : requests) {
      responses.add(buildResponse(request?.sessionKey?.trim(), ctx));
    }
    return responses;
  }

  private class ResponseContext {
    public Map<String, Id> caseIdsByKey;
    public Map<String, Case> newCasesByKey;
    public Map<String, String> failuresByKey;
    public Set<String> answeredKeys;
    public ResponseContext(Map<String, Object> combined) {
      this.caseIdsByKey = (Map<String, Id>) combined.get('caseIdsByKey');
      this.newCasesByKey = (Map<String, Case>) combined.get('newCasesByKey');
      this.failuresByKey = (Map<String, String>) combined.get('failuresByKey');
      this.answeredKeys = new Set<String>();
    }
  }

  private static Response buildResponse(String key, ResponseContext ctx) {
    if (String.isBlank(key)) {
      return new Response(OUTCOME_MISSING_SESSION_KEY, null);
    }
    Case newCase = ctx.newCasesByKey.get(key);
    Boolean isFirstAnswer = ctx.answeredKeys.add(key);
    if (newCase?.Id != null) {
      return new Response(
        isFirstAnswer ? OUTCOME_CREATED : OUTCOME_EXISTING,
        newCase.Id
      );
    }
    if (ctx.caseIdsByKey.containsKey(key)) {
      return new Response(OUTCOME_EXISTING, ctx.caseIdsByKey.get(key));
    }
    return new Response(OUTCOME_FAILED, null, ctx.failuresByKey.get(key));
  }

  private static Case buildCase(
    Request request,
    String key,
    Map<Id, Id> contactIdsByOrderId
  ) {
    Id contactId = getVerifiedContactId(request);
    Id orderId = toIdOfType(request.orderId, Order.SObjectType);
    Boolean isOrderOfContact =
      contactId != null &&
      orderId != null &&
      contactIdsByOrderId.get(orderId) == contactId;
    String intent = String.isBlank(request.callerIntent)
      ? DEFAULT_INTENT
      : request.callerIntent.trim();

    return new Case(
      Agent_Session_Key__c = key,
      Origin = CASE_ORIGIN,
      Subject = (SUBJECT_PREFIX + intent).left(SHORT_TEXT_LENGTH),
      ContactId = contactId,
      Is_Identity_Verified__c = contactId != null,
      Related_Order__c = isOrderOfContact ? orderId : null,
      Caller_Intent__c = intent.left(SHORT_TEXT_LENGTH),
      AI_Generated_Call_Summary__c = request.aiSummary?.left(LONG_TEXT_LENGTH),
      Caller_Stated_Details__c = request.callerStatedDetails
        ?.left(LONG_TEXT_LENGTH)
    );
  }

  private static Map<String, String> insertCases(
    Map<String, Case> newCasesByKey
  ) {
    Map<String, String> failuresByKey = new Map<String, String>();
    if (newCasesByKey.isEmpty()) {
      return failuresByKey;
    }
    List<String> keys = new List<String>(newCasesByKey.keySet());
    List<Case> newCases = new List<Case>();
    for (String key : keys) {
      newCases.add(newCasesByKey.get(key));
    }
    List<Database.SaveResult> results = Database.insert(
      newCases,
      false,
      AccessLevel.USER_MODE
    );
    for (Integer index = 0; index < results.size(); index++) {
      if (!results[index].isSuccess()) {
        failuresByKey.put(
          keys[index],
          String.valueOf(results[index].getErrors()[0].getStatusCode())
        );
      }
    }
    return failuresByKey;
  }

  private static Map<String, Id> getCaseIdsByKey(Set<String> sessionKeys) {
    Map<String, Id> caseIdsByKey = new Map<String, Id>();
    if (sessionKeys.isEmpty()) {
      return caseIdsByKey;
    }
    for (Case existingCase : [
      SELECT Id, Agent_Session_Key__c
      FROM Case
      WHERE Agent_Session_Key__c IN :sessionKeys
      WITH USER_MODE
      ORDER BY CreatedDate ASC NULLS LAST, Id
      LIMIT :MAX_ROWS
    ]) {
      caseIdsByKey.put(existingCase.Agent_Session_Key__c, existingCase.Id);
    }
    return caseIdsByKey;
  }

  private static Map<Id, Id> getBillToContactIdsByOrderId(
    Set<Id> orderIds,
    Set<Id> contactIds
  ) {
    Map<Id, Id> contactIdsByOrderId = new Map<Id, Id>();
    if (orderIds.isEmpty()) {
      return contactIdsByOrderId;
    }
    for (Order verifiedOrder : [
      SELECT Id, BillToContactId
      FROM Order
      WHERE Id IN :orderIds AND BillToContactId IN :contactIds
      WITH USER_MODE
      ORDER BY Id
      LIMIT :MAX_ROWS
    ]) {
      contactIdsByOrderId.put(verifiedOrder.Id, verifiedOrder.BillToContactId);
    }
    return contactIdsByOrderId;
  }

  private static Id getVerifiedContactId(Request request) {
    return request.isVerified == true
      ? toIdOfType(request.verifiedContactId, Contact.SObjectType)
      : null;
  }

  private static Id toIdOfType(String value, Schema.SObjectType expectedType) {
    if (String.isBlank(value)) {
      return null;
    }
    try {
      Id candidate = Id.valueOf(value.trim());
      return candidate.getSObjectType() == expectedType ? candidate : null;
    } catch (StringException invalidId) {
      return null;
    }
  }

  /**
   * Input from the agent. Session key, verified state, contact and order come from
   * protected agent variables; intent, summary and stated details come from the model.
   */
  public class Request {
    @InvocableVariable(
      label='Session Key'
      description='Voice call id, messaging session id or agent session id from runtime context. Never from the caller or the model. Blank returns MISSING_SESSION_KEY.'
      required=false
    )
    public String sessionKey;

    @InvocableVariable(
      label='Is Verified'
      description='True only when the verification step succeeded.'
    )
    public Boolean isVerified;

    @InvocableVariable(
      label='Verified Contact Id'
      description='Contact id stored by the verification step.'
    )
    public String verifiedContactId;

    @InvocableVariable(
      label='Order Id'
      description='Order id returned as FOUND by the order lookup.'
    )
    public String orderId;

    @InvocableVariable(
      label='Caller Intent'
      description='Short reason for the call, for example order status.'
    )
    public String callerIntent;

    @InvocableVariable(
      label='AI Summary'
      description='Short AI-generated summary of the call for the rep.'
    )
    public String aiSummary;

    @InvocableVariable(
      label='Caller Stated Details'
      description='Unverified details the caller said, such as an order number.'
    )
    public String callerStatedDetails;
  }

  /**
   * Result for the agent.
   */
  public class Response {
    @InvocableVariable(
      label='Outcome'
      description='CREATED, EXISTING, MISSING_SESSION_KEY or FAILED.'
    )
    public String outcome;

    @InvocableVariable(
      label='Case Id'
      description='Id of the created or existing handoff case.'
    )
    public String caseId;

    @InvocableVariable(
      label='Error Type'
      description='Status code or exception type on FAILED, for support logs. Not for the caller.'
    )
    public String errorType;

    public Response(String outcome, Id caseId) {
      this.outcome = outcome;
      this.caseId = caseId;
    }

    public Response(String outcome, Id caseId, String errorType) {
      this(outcome, caseId);
      this.errorType = errorType;
    }
  }
}
