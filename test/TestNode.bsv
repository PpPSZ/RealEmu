import GetPut::*;
import Connectable::*;
import ClientServer::*;
import Vector::*;
import StmtFSM::*;
import FIFOF::*;

import Types::*;
import MacCore::*;
import CsmaUtils::*;
import PrimUtils::*;
import PhyCoreSim::*;
import Channel::*;
import Arbitration::*;

module mkTestTop(Empty);
    // ==================== 节点实例化 ====================
        Vector#(NODE_NUM, MacCore) macNodes <- genWithM(compose(mkMacDCF, fromInteger));
        Vector#(NODE_NUM, PhyCore) phyNodes <- genWithM(compose(mkPhyYansWifi, fromInteger));
        Vector#(NODE_NUM, GainLossModel) channels <- replicateM(mkGainLossModelIdeal);
        ArbiterIFC pollController <- mkArbiter;
        
        // ==================== 控制寄存器 ====================
        Reg#(UInt#(64)) cycleCount <- mkReg(3);
        // ==================== 初始化 ====================

        // FIFOF#(Bool) test <- mkFIFOF;

        // rule testPut;
        //     let testValue <- test.first;
        //     $display("testPut");
        // endrule

        // rule testput if(cycleCount == 10);
        //     test.enq(True);
        // endrule

        rule updateclock;
            cycleCount <= cycleCount + 1;
        endrule

        // ==================== 节点连接 ====================
        for(Integer i=0; i<valueOf(NODE_NUM); i=i+1) begin
            mkConnection(macNodes[i].lowMacTxClt, phyNodes[i].lowMacTxSrv);
            mkConnection(macNodes[i].lowMacRxSrv, phyNodes[i].lowMacRxClt);
            mkConnection(phyNodes[i].phyTxClt, channels[i].phyTxSrv);
            mkConnection(phyNodes[i].phyRxSrv, channels[i].phyRxClt);
            mkConnection(pollController.phyTxMetaClt[i], channels[i].phyRxMetaSrv);
            mkConnection(pollController.phyRxMetaSrv[i], channels[i].phyTxMetaClt);
        end
      
        rule updatePhyStatus;
            for (Integer i = 0; i < valueOf(NODE_NUM); i = i + 1) begin
                let phyStatus = phyNodes[i].getPhyStatus;
                macNodes[i].phyStatus.put(phyStatus);
            end
        endrule

        for(Integer i=0; i<valueOf(NODE_NUM); i=i+1) begin
            rule handshake;
                let resp <- macNodes[i].highMacTxSrv.response.get;
            endrule
        end

        rule send ;
            let txReq = getEmptyMacEvent;
            txReq.srcMacId = 1;
            txReq.dstMacId = 0;
            txReq.mpduDigest.frameType = fromInteger(valueOf(FC_TYPE_DATA));
            //txReq.mpduDigest.length = NODE_NUM048;
            txReq.rfParam.power = 60*32;
            txReq.mpduDigest.length = 1; //使长度变化，用于每次打印出不同的rxReq
            txReq.rfParam.mcs = 7;
            macNodes[1].highMacTxSrv.request.put(txReq);
        endrule


        rule receive;
            let rxReq <- macNodes[0].highMacRxClt.request.get;
        endrule


        rule simEnd if(cycleCount == 1000*1000);
            $display("end");
            $finish();
        endrule

endmodule