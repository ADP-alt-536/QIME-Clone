public class QBPaymentResponseJSON {

    public class CustomerRef {
        public String value;
        public String name;
    }

    public class Payment {
        public String Id;
        public String SyncToken;
        public Double TotalAmt;
        public String TxnDate;
        public CustomerRef CustomerRef;
        public Boolean sparse;
        public String domain;
    }

    public Payment Payment;
    public String time;

    public static QBPaymentResponseJSON parse(String json) {
        return (QBPaymentResponseJSON) System.JSON.deserialize(json, QBPaymentResponseJSON.class);
    }
}
