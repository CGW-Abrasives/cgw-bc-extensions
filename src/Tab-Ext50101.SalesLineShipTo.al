tableextension 50101 "CGW SalesLine Ext" extends "Sales Line"
{
    fields
    {
        field(50100; "CGW Ship-to Code"; Code[10])
        {
            Caption = 'Line Ship-to Code';
            DataClassification = CustomerContent;
            TableRelation = "Ship-to Address".Code WHERE("Customer No." = FIELD("Sell-to Customer No."));
        }
    }
}
