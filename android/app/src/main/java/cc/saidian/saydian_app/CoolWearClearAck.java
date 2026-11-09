package cc.saidian.saydian_app;

import ce.com.cenewbluesdk.entity.CEDevData;

/** Exact SDK history-clear envelope and its command-result contract. */
final class CoolWearClearAck {
    enum Reply { IGNORE, CONFIRMED, REJECTED }

    private CoolWearClearAck() { }

    static CEDevData request() {
        // Identical to bundled K6SendDataManager.sendClearData(). No reset.
        CEDevData request = new CEDevData(1, 207);
        request.setItemL(1);
        request.setItemNumber(1);
        request.setData(new byte[]{1});
        return request;
    }

    static Reply reply(CEDevData sent, int status) {
        if (sent == null || sent.getCmd() != 1 || sent.getDataType() != 207
                || sent.getItemL() != 1 || sent.getItemNumber() != 1
                || sent.getData() == null || sent.getData().length != 1 || sent.getData()[0] != 1)
            return Reply.IGNORE;
        if (status == 1) return Reply.CONFIRMED;
        if (status == 0) return Reply.REJECTED;
        return Reply.IGNORE;
    }
}
