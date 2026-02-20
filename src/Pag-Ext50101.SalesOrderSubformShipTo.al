pageextension 50101 "CGW SalesLine ShipTo Ext" extends "Sales Order Subform"
{
    layout
    {
        addafter("Location Code")
        {
            field("CGW Ship-to Code"; Rec."CGW Ship-to Code")
            {
                ApplicationArea = All;
                Caption = 'Line Ship-to Code';
                ToolTip = 'Specifies a ship-to code for this specific line.';
                Visible = true;
            }
            // Note: True "Ship-to Code" on Line usually requires "Drop Shipment" = true or "Special Order".
            // If you just want the code, we might need "Purchasing Code" or just "Drop Shipment".
            // BUT, standard Sales Line table DOES NOT have "Ship-to Code" field directly in all versions.
            // It often relies on header.
            // However, "Drop Shipment" functionality uses the header's ship-to or a custom one.
            
            // Actually, let's use the field we KNOW exists if Ship-to Code is missing.
            // Wait, standard BC DOES have "Ship-to Code" (ID 12) but maybe it was removed or renamed?
            // Let's try "Location Code" or verify via symbol download.
            // Since we can't browse symbols here, let's assume the user wants "Alternate Ship-to".
            // Error says 'Ship-to Code' does not exist.

        }
    }
}
