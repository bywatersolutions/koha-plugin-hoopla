function HooplaSearch( querystring, callback ) {
    $.get('/api/v1/contrib/hoopla/search/'+querystring).done(function(data){
        callback(data);
    }).fail(function(data){
        console.log("Error when searching");
    });
}

function AddHooplaActions() {
    $.get('/api/v1/contrib/hoopla/status/').done(function(data){
            console.log( data );
        $(".hoopla_result").each(function(){
            if( data.borrowsRemaining > 0 ){
              $(this).append("<button>Checkout</button>");
            } else {
              $(this).append("<p id='hoopla_out_of_borrows'>No more Hoopla borrows</p>");
            }
        });
    }).fail(function(data){
        if( data.error == 'not_signed_in' ) {
            $(".hoopla_result").append("<p>Please sign in to see Hoopla availability</p>");
        } else {
            $(".hoopla_result").append("<p>You must sign up with Hoopla to checkot items</p>");
        };

    });
}

$(document).ready(function(){


    $("#numresults").on('click','#hoopla_results',function(){
            $("#hoopla_modal").modal("show");
    });
    //Add link to search results
    $(document).ready(function(){
        HooplaSearch( $("#translControl1").val(), function(data){
            $("#numresults").append('<div id="hoopla_results"><a href="#">Found ' + data.found + ' results in Hoopla</a></div>');
            $.each(data.titles,function(index,value){
                $("#hoopla_modal_results").append('<tr><td><img src="'+value.coverImageUrl+'"></td><td>'+value.title+'</br>'+value.artist+'</br><span class="hoopla_result" data-content_id="'+data.titleId+'"><span></td></tr>');
            });
            AddHooplaActions();
        });

    });
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
            $('a[href*="ebook.yourcloudlibrary.com"]').closest('td').children('.availability').html('<td class="item_status"><span class="action">Login to see Cloud Availability</span></td>');
        } else {
            var item_ids = "";
            var counter = 0;
            $("a[href*='ebook.yourcloudlibrary.com']").each(function(){
                var cloud_id = $(this).attr('href').split('-').pop().split('&').shift();
                console.log( cloud_id );
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
        $("a[href*='ebook.yourcloudlibrary.com']").each(function(){
            var cloud_id = $(this).attr('href').split('-').pop().split('&').shift();
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
        $("a[href*='ebook.yourcloudlibrary.com']").each(function(){
            var cloud_id = $(this).attr('href').split('-').pop().split('&').shift();
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
        var cloud_link = $("a[href*='ebook.yourcloudlibrary.com']").first();
        if ( cloud_link.length ){
            if( $(".loggedinusername").length == 0 ){
                $("#holdings").append('<h3>Login to see CloudLibrary Availability</h3>');
            } else {
                var cloud_id = cloud_link.attr('href').split('-').pop().split('&').shift();
                $("#holdings").append('<h3>CloudLibrary item(s)</h3><span id="'+cloud_id+'" class="item_status" ><span class="action"><img src="/plugin/Koha/Plugin/Com/ByWaterSolutions/Bibliotheca/img/spinner-small.gif"> Fetching 3M Cloud Availability</span><span class="detail"></span></span>');
                CloudItemStatus( cloud_id );
            }
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

