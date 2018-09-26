//Return some item info for display
function CloudItemInfo(item_ids) {
    params = { item_ids: item_ids, action: 'info',};
    $.get("/plugin/Koha/Plugin/Com/ByWaterSolutions/Bibliotheca/item_actions.pl",params,function(data){
        }).done(function(data){
            $(data).find('DocumentData').each(function(){
                var item_id = $(this).find('id').text();
                var item_title = $(this).find('title').text();
                var item_author = $(this).find('author').text();
                var item_cover = $(this).find('coverimage').text();
                var item_isbn = $(this).find('isbn').text();
                $('#'+item_id).children('.detail').html('<a href="#" class="cloud_cover" id="'+item_isbn+'"><img src='+item_cover+' /></a>' );
            });
        }).fail(function(data){
            console.log(data)
        });
}

//Returns item info, most importantly link and cover
function CloudIsbnInfo(item_isbns) {
    params = { item_ids: item_isbns, action: 'isbn_info',};
    $.get("/plugin/Koha/Plugin/Com/ByWaterSolutions/Bibliotheca/item_actions.pl",params,function(data){
        }).done(function(data){
            $(data).find('LibraryDocumentSummary').each(function(){
                var item_id = $(this).find('id').text();
                var item_title = $(this).find('title').text();
                var item_author = $(this).find('author').text();
                var item_cover = $(this).find('coverimage').text();
                var item_isbn = $(this).find('isbn').text();
                var item_link = $(this).find('itemlink').text();
                $('#'+item_id).children('.detail').html('<a href="'+item_link+'" class="cloud_cover" id="'+item_isbn+'" target="_blank"><img style="max-height:150px;" src='+item_cover+' /></a>' );
            });
        }).fail(function(data){
            console.log(data)
        });
}

//Returns availability of item for a patron
function CloudItemStatus(item_ids) {
    params = { item_ids: item_ids, action: 'status',};
    $.get("/plugin/Koha/Plugin/Com/ByWaterSolutions/Bibliotheca/item_actions.pl",params,function(data){
        }).done(function(data){
            console.log( data );
            if( $(data).find('DocumentStatus').length == 0 ) {
                $('.item_status').html('Error fetching availability - please see library for assistance');
                return;
            }
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
                    $('#'+item_id).children('.action').html('Item is checked out <button type="button" class="cloud_action" action="checkin" value='+item_id+'>Return</button');
                } else if ( item_status == "RESERVATION") {
                    $('#'+item_id).children('.action').html('<button type="button" class="cloud_action" action="checkout" value='+item_id+'>Checkout reserve</button');
                } else {
                    $('#'+item_id).children('.action').text( item_status );
                }
            });
        }).fail(function(data){
            console.log('failure');
            console.log(data)
        });
}

//Returns library availability of item 
function CloudItemSummary(item_ids) {
    params = { item_ids: item_ids, action: 'summary',};
    $.get("/plugin/Koha/Plugin/Com/ByWaterSolutions/Bibliotheca/item_actions.pl",params,function(data){
        }).done(function(data){
            console.log( data );
            if( $(data).find('LibraryDocumentSummary').length == 0 ) {
                $('.item_status').html('Error fetching availability - please see library for assistance');
                return;
            }
            $(data).find('LibraryDocumentSummary').each(function(){
                var item_id = $(this).find('id').text();
                $(this).find('LibraryDocumentDetail').each(function(){
                    if ( $(this).find('libraryid').text() == our_cloud_lib ) {
                        var item_copies = $(this).find('ownedCopies').text();
                        var loan_copies = $(this).find('loanCopies').text();
                        var hold_copies = $(this).find('holdCopies').text();
                        $('#'+item_id).children('.cloud_copies').text(item_copies + " Total copies " +
                        loan_copies + " On loan, " +
                        hold_copies + " On hold");
                    }
                });
            });
        }).fail(function(data){
            console.log('failure');
            console.log(data)
        });
}

// This function calls for the patron status, then gets item status and info for each checkout/hold
function GetPatronInfo(){
    $.get("/plugin/Koha/Plugin/Com/ByWaterSolutions/Bibliotheca/patron_info.pl",function(data){
        }).done(function(data){
            var item_ids="";
            var item_isbns="";
            if( $(data).find('checkouts').find('item').length > 0 ){
                $("#content-3m").append('<h1>Checkouts</h1><div class="span12 container-fluid" id="cloud_checkouts"></div>');
                $(data).find('checkouts').find('item').each(function(){
                    $("#cloud_checkouts").append('<div class="col span2 cloud_items"  id="'+$(this).find('itemid').text()+'" codate="'+$(this).find('eventstartdateinutc').text()+'" duedate="'+$(this).find('eventenddateinutc').text()+'"><span class="detail"></span><br><span class="action"></span></div>');
                    item_ids += $(this).find('itemid').text()+",";
                    item_isbns += $(this).find('isbn').text()+",";
                });
            } else {
                $("#content-3m").append('<h1>Checkouts</h1><ul id="cloud_checkouts"><li>No items currently checked out</li></ul>');
            }
            if( $(data).find('holds').find('item').length > 0 ){
                $("#content-3m").append('<h1>Holds</h1><div class="span12 container-fluid" id="cloud_holds"></div>');
                $(data).find('holds').find('item').each(function(){
                    $("#cloud_holds").append('<div class="col span2 cloud_items" id="'+$(this).find('itemid').text()+'" holddate="'+$(this).find('eventstartdateinutc').text()+'" holdedate="'+$(this).find('eventenddateinutc').text()+'"><span class="action"></span><span class="detail"></span></div>');
                    item_ids += $(this).find('itemid').text()+",";
                    item_isbns += $(this).find('isbn').text()+",";
                });
            } else {
                $("#content-3m").append('<h1>Holds</h1><ul id="cloud_holds"><li>No items on hold</li></ul>');
            }
            if( $(data).find('reserves').find('item').length > 0 ){
                $("#content-3m").append('<h1>Holds ready to checkout</h1><div id="cloud_reserves"></div>');
                $(data).find('reserves').find('item').each(function(){
                    $("#cloud_reserves").append('<div  class="span12 container-fluid" id="'+$(this).find('itemid').text()+'" reservedate="'+$(this).find('eventstartdateinutc').text()+'" reserveexpiredate="'+$(this).find('eventenddateinutc').text()+'"><span class="action"></span><span class="detail"></span> Expires:'+$(this).find('eventenddateinutc').text()+'</div>');
                    item_ids += $(this).find('itemid').text()+",";
                    item_isbns += $(this).find('isbn').text()+",";
                });
            } else {
                $("#content-3m").append('<h1>Holds ready to checkout</h1><ul id="cloud_holds"><li>No holds ready for checkout</li></ul>');
            }
            if( item_ids.length > 0 ) {CloudItemStatus( item_ids.slice(0,-1) );}
            if( item_isbns.length > 0 ) {CloudIsbnInfo( item_isbns.slice(0,-1) );}
        }).fail(function(data){
            console.log(data);
        });
}

$(document).ready(function(){

    //Creates and populates the 3m Checkouts tab on patron summary on OPAC
    if( $("body#opac-user").length > 0 ) {
        $("#opac-user-views ul").append('<li><a href="#opac-user-cloudlibrary">Cloud Library Account</a></li>');
        $("#opac-user-views").append('<div id="opac-user-cloudlibrary"><div id="content-3m">Search the catalog to find and place holds or checkout Cloud Library items. Click the covers to visit the Cloud Library site and login to download items or get the apps</div></div>');
        $('#opac-user-views').tabs("refresh");
        GetPatronInfo();
    }

    //Fetches status info for OPAC results page
    if( $("body#results").length > 0 ) {
    console.log("ok");
        if( $(".loggedinusername").length == 0 ){
            $("a[href^='https://ebook.yourcloudlibrary.com']'").closest('td').children('.availability').html('<td class="item_status"><span class="action">Login to see Cloud Availability</span></td>');
        } else {
            var item_ids = "";
            var counter = 0;
            $("a[href^='https://ebook.yourcloudlibrary.com']'").each(function(){
                var cloud_id = $(this).attr('href').split('-').pop();
                $(this).closest('td').children('.availability').html('<td id="'+cloud_id+'" class="item_status" ><span class="action"><img src="/plugin/Koha/Plugin/Com/ByWaterSolutions/Bibliotheca/img/spinner-small.gif"> Fetching 3M Cloud availability</span><span class="detail"></span></td>');
                item_ids += cloud_id+",";
                counter++;
                if(counter >= 25){
                    CloudItemStatus(item_ids);
                    counter = 0;
                    item_ids = "";
                }
            });
            if( item_ids.length > 0 ) { CloudItemStatus(item_ids);}
        }
    }

    //Fetches status info for staff results page
    if( $("body#catalog_results").length > 0 ) {
        var item_ids = "";
        var counter = 0;
        $("a[href^='https://ebook.yourcloudlibrary.com']").each(function(){
            var cloud_id = $(this).attr('href').split('-').pop();
            $(this).closest('td').append('<span id="'+cloud_id+'" class="results_summary item_status" ><span class="cloud_copies"><img src="/plugin/Koha/Plugin/Com/ByWaterSolutions/Bibliotheca/img/spinner-small.gif"> Fetching 3M Cloud availability</span><span class="detail"></span></td>');
            item_ids += cloud_id+",";
            counter++;
            if(counter >= 25){
                CloudItemSummary(item_ids);
                counter = 0;
                item_ids = "";
            }
        });
        if( item_ids.length > 0 ) { CloudItemSummary(item_ids);}
    }

    //Fetches status info for staff details page
    if( $("body#catalog_detail").length > 0 ) {
        var item_ids = "";
        var counter = 0;
        $("a[href^='https://ebook.yourcloudlibrary.com']").each(function(){
            var cloud_id = $(this).attr('href').split('-').pop();
            $("#holdings").append('<h3>CloudLibrary item(s)</h3><span id="'+cloud_id+'" class="results_summary item_status" ><span class="cloud_copies"><img src="/plugin/Koha/Plugin/Com/ByWaterSolutions/Bibliotheca/img/spinner-small.gif"> Fetching 3M Cloud availability</span><span class="detail"></span></td>');
            item_ids += cloud_id+",";
            counter++;
            if(counter >= 25){
                CloudItemSummary(item_ids);
                counter = 0;
                item_ids = "";
            }
        });
        if( item_ids.length > 0 ) { CloudItemSummary(item_ids);}
    }

    //Fetches status info for details page and append to holdings
    if( $("body#opac-detail").length > 0 ) {
        if( $(".loggedinusername").length == 0 ){
            $("#holdings").append('<h3>Login to see CloudLibrary Availability</h3>');
        } else {
            var item_ids = "";
            var counter = 0;
            $("a[href^='https://ebook.yourcloudlibrary.com']'").each(function(){
                var cloud_id = $(this).attr('href').split('-').pop();
                $("#holdings").append('<h3>CloudLibrary item(s)</h3><span id="'+cloud_id+'" class="item_status" ><span class="action"><img src="/plugin/Koha/Plugin/Com/ByWaterSolutions/Bibliotheca/img/spinner-small.gif"> Fetching 3M Cloud Availability</span><span class="detail"></span></span>');
                item_ids += cloud_id+",";
                counter++;
                if(counter >= 25){
                    CloudItemStatus(item_ids);
                    counter = 0;
                    item_ids = "";
                }
            });
            if( item_ids.length > 0 ) { CloudItemStatus(item_ids);}
        }
    }

    //Handle action buttons
    $(document).on('click',".cloud_action",function(){
        var item_id = $(this).val();
        var action = $(this).attr('action');
        $(this).parent("span.action").html('<img src="/plugin/Koha/Plugin/Com/ByWaterSolutions/Bibliotheca/img/spinner-small.gif">');
        $('#'+item_id).children('.detail').text("");
        var params = {
            action : action,
            item_id : $(this).val(),
        };
        $.get("/plugin/Koha/Plugin/Com/ByWaterSolutions/Bibliotheca/cloud_actions.pl",params,function(data){
        }).done(function(data){
            CloudItemStatus( item_id );
            if ( action == 'checkout')   {
                //$('#'+item_id).children('.detail').text( $(data).find('DueDateInUTC').text() );
                alert('Item checked out, due:'+$(data).find('DueDateInUTC').text() );
            }
            if ( action == 'place_hold') { $('#'+item_id).children('.detail').text( $(data).find('AvailabilityDateInUTC').text() ); }
            if( action == 'checkin' && $("#opac-user").length > 0 ) { $('div#'+item_id).remove(); }
        }).fail(function(){
            alert('There was an issue with this action, please try again later or contact the library if the problem persists');
        });
    });

});
