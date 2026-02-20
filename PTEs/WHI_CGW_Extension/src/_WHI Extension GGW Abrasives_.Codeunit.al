codeunit 50800 "WHI Extension GGW Abrasives"
{
    var iEventID: Integer;
    cuCommonFuncs: Codeunit "WHI Common Functions";
    cuActivityLogMgt: Codeunit "WHI Activity Log Mgmt.";
    cuWhseActivityMgmt: Codeunit "WHI Whse. Activity Mgmt.";
    cuRegistrationMgmt: Codeunit "WHI Registration Mgmt.";
    [EventSubscriber(ObjectType::Codeunit, 23044908, 'OnBeforeProcessEvent', '', false, false)]
    local procedure onBeforeProcessEvent(piEventID: Integer; var precEventParams: Record "IWX Event Param"; var pbtxtOutput: BigText; var pbOverrideWHI: Boolean);
    begin
        iEventID:=piEventID;
        CASE iEventID OF // //New event
        // 123000003:
        //     DeleteItemTracking_InvPut(precEventParams, pbtxtOutput, pbOverrideWHI);
        //Overriding existing event
        20008: getWhseActivityList(precEventParams, pbtxtOutput, pbOverrideWHI);
        end;
    end;
    [EventSubscriber(ObjectType::Codeunit, 23044908, 'OnAfterProcessEvent', '', false, false)]
    local procedure onAfterProcessEvent(piEventID: Integer; var precEventParams: Record "IWX Event Param"; var pbtxtOutput: BigText);
    begin
        iEventID:=piEventID;
        CASE iEventID OF end;
    end;
    local procedure getWhseActivityList(var ptrecEventParams: Record "IWX Event Param" temporary; var pbsOutput: BigText; var pbOverrideWHI: Boolean);
    var
        lrecWHISetup: Record "WHI Setup";
        lrecConfig: Record "WHI Device Configuration";
        ltrecDocList: Record "WHI Document List Buffer" temporary;
        lcuDataSetTools: Codeunit "WHI Dataset Tools";
        lrrefDocListRef: RecordRef;
        ldnOutput: TextBuilder;
        lcodUserName: Code[50];
        liActivityType: Integer;
        lsFilter: Text;
        liMaxDocList: Integer;
        lcodOptionalItem: Code[20];
        lcodLot: Code[50];
        lcodSerial: Code[50];
        lbOnlyAssignedDocs: Boolean;
    begin
        liActivityType:=ptrecEventParams.getValueAsInt('document_type');
        lcodUserName:=CopyStr(ptrecEventParams.GetExtendedValue('user_name'), 1, MaxStrLen(lcodUserName));
        lsFilter:=EscapeFilterString(ptrecEventParams.GetExtendedValue('filter'));
        lcodOptionalItem:=CopyStr(ptrecEventParams.GetExtendedValue('item_number'), 1, MaxStrLen(lcodOptionalItem));
        lcodLot:=CopyStr(ptrecEventParams.GetExtendedValue('lot_number'), 1, MaxStrLen(lcodLot));
        lcodSerial:=CopyStr(ptrecEventParams.GetExtendedValue('serial_number'), 1, MaxStrLen(lcodSerial));
        if lcodOptionalItem <> '' then lsFilter:='';
        cuCommonFuncs.getDeviceConfig(lrecConfig, ptrecEventParams);
        lbOnlyAssignedDocs:=(lcodUserName <> '') and (lrecConfig."Show All Documents" = lrecConfig."Show All Documents"::No);
        lrecWHISetup.Get();
        liMaxDocList:=lrecWHISetup."Document Max List";
        if liMaxDocList = 0 then liMaxDocList:=999999;
        searchActivityDocuments(ltrecDocList, lrecConfig, ptrecEventParams, lbOnlyAssignedDocs, lcodUserName, lsFilter, liMaxDocList, lcodOptionalItem, liActivityType, lcodLot, lcodSerial);
        ltrecDocList.Reset();
        if((ltrecDocList.Count() = 0) and (liActivityType = 1) and (lcodOptionalItem <> ''))then cuWhseActivityMgmt.searchPostedReceipts(ltrecDocList, lrecConfig, liMaxDocList, lcodOptionalItem, lcodLot, lcodSerial);
        ltrecDocList.Reset();
        lrrefDocListRef.GetTable(ltrecDocList);
        if(lrrefDocListRef.FindFirst())then;
        lcuDataSetTools.BuildLinesOnlyDataset(iEventID, lrrefDocListRef, false, ldnOutput);
        pbsOutput.AddText(ldnOutput.ToText());
        cuActivityLogMgt.logActivity(ptrecEventParams);
        pbOverrideWHI:=TRUE;
    end;
    procedure searchActivityDocuments(var ptrecDocList: Record "WHI Document List Buffer"; var precConfig: Record "WHI Device Configuration"; var ptrecEventParams: Record "IWX Event Param" temporary; pbOnlyAssignedDocs: Boolean; pcodUser: Code[50]; ptxtFilter: Text; piMaxDocCount: Integer; pcodItemNumber: Code[20]; piActivityType: Integer; pcodLotNumber: Code[50]; pcodSerialNumber: Code[50])
    var
        lrecWhseActHeader: Record "Warehouse Activity Header";
        lrecWhseActLine: Record "Warehouse Activity Line";
        lrecLocation: Record Location;
        lrecWhseHeaderTemp: Record "Warehouse Activity Header";
        lrecWhseLineTemp: Record "Warehouse Activity Line";
        lrecSalesHeader: Record "Sales Header";
        lrecPurchHeader: Record "Purchase Header";
        lrecLPUsage: Record "IWX LP Line Usage";
        lbIncludeResult: Boolean;
        liLineCounter: Integer;
        lsName: Text[100];
        lsBarcode: Text[100];
        liType: Integer;
        lbActivitySupported: Boolean;
        lbInvtActivitySupported: Boolean;
    begin
        pcodLotNumber:=UpperCase(pcodLotNumber);
        pcodSerialNumber:=UpperCase(pcodSerialNumber);
        lrecLocation.Get(precConfig."Location Code");
        lrecWhseActHeader.SetRange("Location Code", precConfig."Location Code");
        if(piActivityType = 0)then begin
            lbActivitySupported:=cuRegistrationMgmt.CheckPickSupported(false);
            lbInvtActivitySupported:=cuRegistrationMgmt.CheckInvtPickSupported(false);
            if lbActivitySupported and lbInvtActivitySupported then lrecWhseActHeader.SetFilter(Type, '%1|%2', lrecWhseActHeader.Type::"Pick", lrecWhseActHeader.Type::"Invt. Pick")
            else if lbActivitySupported then lrecWhseActHeader.SetRange(Type, lrecWhseActHeader.Type::"Pick")
                else if lbInvtActivitySupported then lrecWhseActHeader.SetRange(Type, lrecWhseActHeader.Type::"Invt. Pick")
                    else
                        exit;
        end
        else if(piActivityType = 1)then begin
                lbActivitySupported:=cuRegistrationMgmt.CheckPutawaySupported(false);
                lbInvtActivitySupported:=cuRegistrationMgmt.CheckInvtPutawaySupported(false);
                if lbActivitySupported and lbInvtActivitySupported then lrecWhseActHeader.SetFilter(Type, '%1|%2', lrecWhseActHeader.Type::"Put-away", lrecWhseActHeader.Type::"Invt. Put-away")
                else if lbActivitySupported then lrecWhseActHeader.SetRange(Type, lrecWhseActHeader.Type::"Put-away")
                    else if lbInvtActivitySupported then lrecWhseActHeader.SetRange(Type, lrecWhseActHeader.Type::"Invt. Put-away")
                        else
                            exit;
            end
            else
            begin // move or inventory movement
                lbActivitySupported:=cuRegistrationMgmt.CheckMovementSupported(false);
                lbInvtActivitySupported:=cuRegistrationMgmt.CheckInvtMovementSupported(false);
                if lbActivitySupported and lbInvtActivitySupported then lrecWhseActHeader.SetFilter(Type, '%1|%2', lrecWhseActHeader.Type::"Movement", lrecWhseActHeader.Type::"Invt. Movement")
                else if lbActivitySupported then lrecWhseActHeader.SetRange(Type, lrecWhseActHeader.Type::"Movement")
                    else if lbInvtActivitySupported then lrecWhseActHeader.SetRange(Type, lrecWhseActHeader.Type::"Invt. Movement")
                        else
                            exit;
            end;
        if(pbOnlyAssignedDocs)then lrecWhseActHeader.SetRange("Assigned User ID", pcodUser);
        if cuRegistrationMgmt.IsWHIInstalled()then cuWhseActivityMgmt.OnAfterFilterLookupWhseActivityHeaders(lrecWhseActHeader, pbOnlyAssignedDocs, pcodUser, ptxtFilter);
        if(lrecWhseActHeader.FindSet(false))then repeat lbIncludeResult:=(ptxtFilter = '');
                // check the purchase lines
                lrecWhseActLine.Reset();
                lrecWhseActLine.SetRange("Activity Type", lrecWhseActHeader.Type);
                lrecWhseActLine.SetRange("No.", lrecWhseActHeader."No.");
                lrecWhseActLine.SetFilter("Qty. Outstanding", '>%1', 0);
                if(pcodItemNumber <> '')then lrecWhseActLine.SetRange("Item No.", pcodItemNumber);
                if(pcodLotNumber <> '')then lrecWhseActLine.SetRange("Lot No.", pcodLotNumber);
                if(pcodSerialNumber <> '')then lrecWhseActLine.SetRange("Serial No.", pcodSerialNumber);
                lrecWhseHeaderTemp.Reset();
                lrecWhseHeaderTemp.SetRange(Type, lrecWhseActHeader.Type);
                if cuRegistrationMgmt.IsWHIInstalled()then cuWhseActivityMgmt.OnAfterFilterLookupWhseActivityLines(lrecWhseActLine, ptxtFilter, pcodItemNumber, pcodSerialNumber, pcodLotNumber);
                if(lrecWhseActLine.FindSet(false))then repeat if(ptxtFilter <> '')then begin
                            // check the warehouse activity number
                            lrecWhseHeaderTemp.SetFilter("No.", ptxtFilter);
                            if lrecWhseHeaderTemp.FindSet(false)then repeat lbIncludeResult:=lrecWhseHeaderTemp."No." = lrecWhseActHeader."No.";
                                until((lrecWhseHeaderTemp.Next() = 0) or lbIncludeResult);
                            // check the external document number
                            if(not lbIncludeResult)then begin
                                lrecWhseHeaderTemp.SetRange("No.", lrecWhseActHeader."No.");
                                lrecWhseHeaderTemp.SetFilter("External Document No.", ptxtFilter);
                                lbIncludeResult:=lrecWhseHeaderTemp.Count() > 0;
                            end;
                            // check the source number
                            if(not lbIncludeResult)then begin
                                lrecWhseLineTemp.Reset();
                                lrecWhseLineTemp.SetRange("Activity Type", lrecWhseActHeader.Type);
                                lrecWhseLineTemp.SetRange("No.", lrecWhseActHeader."No.");
                                lrecWhseLineTemp.SetFilter("Source No.", ptxtFilter);
                                lbIncludeResult:=lrecWhseLineTemp.Count() > 0;
                            end;
                            // check whse. document no.
                            if(not lbIncludeResult)then begin
                                lrecWhseLineTemp.Reset();
                                lrecWhseLineTemp.SetRange("Activity Type", lrecWhseActHeader.Type);
                                lrecWhseLineTemp.SetRange("No.", lrecWhseActHeader."No.");
                                lrecWhseLineTemp.SetFilter("Whse. Document No.", ptxtFilter);
                                lbIncludeResult:=lrecWhseLineTemp.Count() > 0;
                            end;
                            if(not lbIncludeResult)then begin
                                lrecLPUsage.SetRange("License Plate No.", ptxtFilter);
                                if(piActivityType = 0)then // pick
 lrecLPUsage.SetFilter("Source Document", '%1|%2', lrecLPUsage."Source Document"::Pick, lrecLPUsage."Source Document"::"Invt. Pick")
                                else if(piActivityType = 1)then // put-away
 lrecLPUsage.SetFilter("Source Document", '%1|%2', lrecLPUsage."Source Document"::"Put-away", lrecLPUsage."Source Document"::"Invt. Put-away");
                                lrecLPUsage.SetRange("Source No.", lrecWhseActLine."No.");
                                lbIncludeResult:=lrecLPUsage.Count() > 0;
                            end;
                        end;
                        if(lbIncludeResult)then begin
                            lsName:='';
                            if(lrecWhseActLine."Source Document" = lrecWhseActLine."Source Document"::"Sales Order")then begin
                                if(lrecSalesHeader.Get(lrecWhseActLine."Source Subtype", lrecWhseActLine."Source No."))then lsName:=lrecSalesHeader."Sell-to Customer Name";
                            end
                            else if(lrecWhseActLine."Source Document" = lrecWhseActLine."Source Document"::"Purchase Order")then if(lrecPurchHeader.Get(lrecWhseActLine."Source Subtype", lrecWhseActLine."Source No."))then lsName:=lrecPurchHeader."Buy-from Vendor Name";
                            #if V19_OR_HIGHER
                            liType := lrecWhseActHeader.Type.AsInteger();
                            #else 
                            liType:=lrecWhseActHeader.Type;
                            #endif 
                            lsBarcode:='%A%' + StrSubstNo('%1 %2', lrecWhseActHeader."No.", liType);
                            cuWhseActivityMgmt.addWhseActDocToList(ptrecDocList, liLineCounter, (precConfig."Use Source Doc. - Warehouse" = precConfig."Use Source Doc. - Warehouse"::Yes), // use source document
 lrecWhseActLine."No.", // document no
 lrecWhseActLine."Source No.", // source no
 DATABASE::"Warehouse Activity Header", // source table
 lrecWhseActHeader."External Document No.", // reference no
 lrecWhseActHeader."Assigned User ID", // assigned user
 lrecWhseActLine."Due Date", // due date
 lrecWhseActLine."Whse. Document No.", // whse document #
 lsName, // custom text 1
 lsBarcode // barcode
                            );
                        end;
                    until((lrecWhseActLine.Next() = 0) or (liLineCounter >= piMaxDocCount));
            until((lrecWhseActHeader.Next() = 0) or (liLineCounter >= piMaxDocCount))end;
    internal procedure EscapeFilterString(psFilter: Text): Text var
        lsEscapedFilter: Text;
    begin
        if psFilter = '' then exit('');
        lsEscapedFilter:='*' + psFilter + '*';
        if lsEscapedFilter.Contains('&') or lsEscapedFilter.Contains('(') or lsEscapedFilter.Contains(')') or lsEscapedFilter.Contains('|') or lsEscapedFilter.Contains('=')then lsEscapedFilter:='''' + lsEscapedFilter + '''';
        exit(lsEscapedFilter);
    end;
}
