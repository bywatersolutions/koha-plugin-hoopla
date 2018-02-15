function CloudItemInfo(item_ids) {
    params = { item_ids: item_ids, action: 'info',};
    $.get("/plugin/Koha/Plugin/Com/ByWaterSolutions/Bibliotheca/item_actions.pl",params,function(data){
            if(data.returned){
            console.log(data);
            }
        }).done(function(data){
            console.log(data);
            $(data).find('DocumentData').each(function(){
                var item_id = $(this).find('id').text();
                var item_title = $(this).find('title').text();
                var item_author = $(this).find('author').text();
                var item_cover = $(this).find('coverimage').text();
                $('#'+item_id).children('.detail').html("<img src="+item_cover+" />" );
            });
        }).fail(function(data){
            console.log(data)
        });
}

function CloudItemStatus(item_ids) {
    params = { item_ids: item_ids, action: 'status',};
    $.get("/plugin/Koha/Plugin/Com/ByWaterSolutions/Bibliotheca/item_actions.pl",params,function(data){
            if(data.returned){
            console.log(data);
            }
        }).done(function(data){
            $(data).find('DocumentStatus').each(function(){
                var item_id = $(this).find('id').text();
                var item_status = $(this).find('status').text();
                if( item_status == "CAN_LOAN" ){
                    $('#'+item_id).children('.action').html('<button type="button" class="cloud_action" action="checkout" value='+item_id+'>Checkout</button');
                } else if ( item_status == "CAN_HOLD") {
                    $('#'+item_id).children('.action').html('<button type="button" class="cloud_action" action="place_hold" value='+item_id+'>Place hold</button');
                } else if ( item_status == "HOLD") {
                    $('#'+item_id).children('.action').html('<button type="button" class="cloud_action" action="cancel_hold" value='+item_id+'>Cancel hold</button');
                } else if ( item_status == "LOAN") {
                    $('#'+item_id).children('.action').html('<button type="button" class="cloud_action" action="checkin" value='+item_id+'>Return</button');
                } else if ( item_status == "RESERVATION") {
                    $('#'+item_id).children('.action').html('<button type="button" class="cloud_action" action="checkout" value='+item_id+'>Checkout reserve</button');
                } else {
                    $('#'+item_id).children('.action').text( item_status );
                }
            });
        }).fail(function(data){
            console.log(data)
        });
}

function GetPatronInfo(){
    $.get("/plugin/Koha/Plugin/Com/ByWaterSolutions/Bibliotheca/patron_info.pl",function(data){
        }).done(function(data){
            console.log(data);
            var item_ids="";
            if( $(data).find('checkouts').find('item').length > 0 ){
                $("#content-3m").append('<h1>Checkouts</h1><ul id="cloud_checkouts"></ul>');
                $(data).find('checkouts').find('item').each(function(){
                    $("#cloud_checkouts").append('<li class="cloud_items"  id="'+$(this).find('itemid').text()+'" codate="'+$(this).find('eventstartdateinutc').text()+'" duedate="'+$(this).find('eventenddateinutc').text()+'"><span class="action"></span><span class="detail"></span></li>');
                    item_ids += $(this).find('itemid').text()+",";
                });
            } else {
                $("#content-3m").append('<h1>Checkouts</h1><ul id="cloud_checkouts"><li>No items currently checked out</li></ul>');
            }
            if( $(data).find('holds').find('item').length > 0 ){
                $("#content-3m").append('<h1>Holds</h1><ul id="cloud_holds"></ul>');
                $(data).find('holds').find('item').each(function(){
                    $("#cloud_holds").append('<li class="cloud_items" id="'+$(this).find('itemid').text()+'" holddate="'+$(this).find('eventstartdateinutc').text()+'" holdedate="'+$(this).find('eventenddateinutc').text()+'"><span class="action"></span><span class="detail"></span></li>');
                    item_ids += $(this).find('itemid').text()+",";
                });
            } else {
                $("#content-3m").append('<h1>Holds</h1><ul id="cloud_holds"><li>No items on hold</li></ul>');
            }
            if( $(data).find('reserves').find('item').length > 0 ){
                $("#content-3m").append('<h1>Holds ready to checkout</h1><ul id="cloud_reserves"></ul>');
                $(data).find('reserves').find('item').each(function(){
                    $("#cloud_reserves").append('<li class="cloud_items" id="'+$(this).find('itemid').text()+'" reservedate="'+$(this).find('eventstartdateinutc').text()+'" reserveexpiredate="'+$(this).find('eventenddateinutc').text()+'"><span class="action"></span><span class="detail"></span> Expires:'+$(this).find('eventenddateinutc').text()+'</li>');
                    item_ids += $(this).find('itemid').text()+",";
                });
            } else {
                $("#content-3m").append('<h1>Holds</h1><ul id="cloud_holds"><li>No items on hold</li></ul>');
            }
            if( item_ids.length > 0 ) {CloudItemStatus( item_ids.slice(0,-1) );}
            if( item_ids.length > 0 ) {CloudItemInfo( item_ids.slice(0,-1) );}
        }).fail(function(data){
            console.log(data);
        });
}

$(document).ready(function(){
    if( $("body#opac-user").length > 0 ) {
        $("#opac-user-views ul").append('<li><a href="#opac-user-cloudlibrary">Cloud Library Account</a></li>');
        $("#opac-user-views").append('<div id="opac-user-cloudlibrary"><div id="content-3m"></div></div>');
        $('#opac-user-views').tabs("refresh");
        GetPatronInfo();
    }

});
