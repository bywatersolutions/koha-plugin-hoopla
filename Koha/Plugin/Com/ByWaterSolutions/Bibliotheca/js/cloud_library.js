
function CloudItemStatus(item_ids) {
    params = { item_ids: item_ids,};
    $.get("/plugin/Koha/Plugin/Com/ByWaterSolutions/Bibliotheca/item_status.pl",params,function(data){
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
            if( $(data).find('checkouts').find('item').length > 0 ){
                $("#content-3m").append('<h1>Checkouts</h1><ul id="cloud_checkouts"></ul>');
                $(data).find('checkouts').find('item').each(function(){
                    $("#cloud_checkouts").append('<li class="cloud_items"  id="'+$(this).find('itemid').text()+'" codate="'+$(this).find('eventstartdateinutc').text()+'" duedate="'+$(this).find('eventenddateinutc').text()+'"><span class="action"></span><span class="detail></span></li>');
                });
            }
            if( $(data).find('holds').find('item').length > 0 ){
                $("#content-3m").append('<h1>Holds</h1><ul id="cloud_holds"></ul>');
                $(data).find('holds').find('item').each(function(){
                    $("#cloud_holds").append('<li class="cloud_items" id="'+$(this).find('itemid').text()+'" holddate="'+$(this).find('eventstartdateinutc').text()+'" holdedate="'+$(this).find('eventenddateinutc').text()+'"><span class="action"></span><span class="detail></li>');
                });
            }
        }).fail(function(data){
            console.log(data);
        });
}

$(document).ready(function(){
    $("#opac-user-views ul").append('<li><a href="#opac-user-cloudlibrary">Cloud Library Account</a></li>');
    $("#opac-user-views").append('<div id="opac-user-cloudlibrary"><div id="content-3m"></div></div>');
    $('#opac-user-views').tabs("refresh");
    GetPatronInfo():
    var item_ids="";
    $(".cloud_items").each(function(){
        item_ids += $(this).attr('id')+",";
    });
    console.log(item_ids);
    CloudItemStatus(item_ids);

});
