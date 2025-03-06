function HooplaSearch( querystring, callback ) {
    if ( querystring ) {
        $("#numresults").append('<div id="searching_hoopla"><img src="/api/v1/contrib/hoopla/static/img/spinner-small.gif"></div>');
        $.get('/api/v1/contrib/hoopla/search/'+querystring).done(function(data){
            $("#searching_hoopla").remove();
            callback(data);
        }).fail(function(data){
            $("#searching_hoopla").html('<p>Error searching hoopla</p>');
            console.log("Error when searching");
        });
    }
}

function HooplaCheckout( content_id, callback ) {
    $.get('/api/v1/contrib/hoopla/checkout/'+content_id).done(function(data){
        callback(data);
    }).fail(function(data){
        console.log("Error when borrowing");
    });
}

function HooplaCheckin( content_id, callback ) {
    $.get('/api/v1/contrib/hoopla/checkin/'+content_id).done(function(data){
        callback(data);
    }).fail(function(data){
        console.log("Error when returning");
    });
}

function HooplaDetails( content_id, callback ) {
    $.get('/api/v1/contrib/hoopla/details/'+content_id).done(function(data){
        callback(data);
    }).fail(function(data){
        console.log("Error fetching details");
    });
}



function GetHooplaAccount(callback) {
    $.get('/api/v1/contrib/hoopla/status').done(function(data){
        let borrowed_ids = [];
        $.each(data.checkouts, function(index, checkout){
            borrowed_ids.push(checkout.contentId);
        });
        data.borrowed_ids = borrowed_ids;
        callback( data );
    }).fail(function(data){
        if( data.responseText == '{\"error\":\"not_signed_in\"}' ) {
            data.error_text = "<p>Please sign in to see Hoopla availability</p>";
        } else {
            data.error_text = "<p>You must sign up with Hoopla to checkout items</p>";
            data.error_text += '<p><a href="https://www.hoopladigital.com/">Hoopla website</a></p>';
        };
        callback( data );
    });
}


function AddHooplaActions() {
    $(".hoopla_result").html('<img src="/api/v1/contrib/hoopla/static/img/spinner-small.gif">');
    GetHooplaAccount( function(account){
        $(".hoopla_result").each(function(){
            if( account.error ){
                $(this).html( account.error_text );
            } else if( typeof account.borrowsRemaining !== 'undefined' ){
                let content_id = $(this).data("content_id");
                let checkout_id = $.inArray(content_id, account.borrowed_ids);
                if( account.borrowed_ids.length && checkout_id > -1 ){
                    let due_date = new Date(account.checkouts[checkout_id].due * 1000);
                    $(this).html('<button class="hoopla_return" data-content_id="'+content_id+'">Return</button></br>Expires: '+due_date );
                } else if( account.borrowsRemaining > 0 ){
                    $(this).html('<button class="hoopla_borrow" data-content_id="'+content_id+'">Checkout</button>');
                } else {
                    $(this).html("<p id='hoopla_out_of_borrows'>No more Hoopla borrows</p>");
                }
            } else {
                $(this).html("<p id='hoopla_account_error'>There was a problem accessing your hoopla account, please see a staff member for assistance</p>");
            }
        });
    });
}

function add_page_modal(titles, page){
    $.each(titles,function(index,value){
        let result = '<tr class="hoopla_page_'+page+'">';
        result +=      '<td>';
        result +=        '<a href="'+value.url+'" target="_blank"><img src="'+value.coverImageUrl+'"></a>';
        result +=      '</td>';
        result +=      '<td>';
        result +=        value.title+'</br>By: '+value.artist+'</br>Type: '+value.kind+'</br><span class="hoopla_result" data-content_id="'+value.titleId+'"></span>';
        result +=        '<p><a class="btn fetch_details" data-content_id="'+value.titleId+'">Show/hide details</a></p>';
        result +=      '</td>';
        result +=    '</tr>';
        result +=    '<tr class="hoopla_page_'+page+' hoopla_result_bottom">';
        result +=      '<td colspan="2" class="hoopla_details_'+value.titleId+'">';
        result +=      '</td>';
        result +=    '</tr>';
        $("#hoopla_modal_results").append(result);
    });
}


$(document).ready(function(){

    $("body").on('click','.hoopla_borrow',function(){
            let content_id = $(this).data("content_id");
            HooplaCheckout(content_id,function(data){
                AddHooplaActions(); 
            });
    });

    $("body").on('click','.hoopla_return',function(){
            let content_id = $(this).data("content_id");
            HooplaCheckin(content_id,function(data){
                AddHooplaActions(); 
            });
    });

    $("body").on('click','.fetch_details',function(){
            let content_id = $(this).data("content_id");
            let hoopla_result = $('td.hoopla_details_'+content_id);
            if( hoopla_result.text() != "" ){
                hoopla_result.toggle();
            } else {
                HooplaDetails(content_id,function(data){
                    let details = '';
                    if( data != "" ){
                        if( data.kind == 'MUSIC' ){
                            $.each(data.segments,function(index, value){
                                let track_num = index+1
                                details += track_num+ ". " + value.name + '</br>';
                            });
                        } else {
                            details = data.synopsis
                        }
                    } else {
                        details = "Could not fetch details for this title";
                    }
                    hoopla_result.append('<span class="hoopla_details">'+details+'</span>');
                });
            }
    });

    $("#numresults").on('click','#hoopla_results',function(){
            $("#hoopla_modal").modal('show');
    });

    $("body").on('click','.hoopla_page',function(){
        let current_page = $('.hoopla_current_page').data('page');
        let new_page;
        let maxpage = $("#hoopla_results").data('maxpage');
        switch( $(this).data('page') ){
            case 'first':
                new_page = 1;
                break;
            case 'next':
                new_page = current_page + 1;
                if( new_page > maxpage ){ new_page = current_page; }
                break;
            case 'previous':
                new_page = current_page - 1;
                if( new_page == 0 ){ new_page = 1; }
                break;
            case 'last':
                new_page = maxpage;
                break;
        }
        if( new_page == current_page ){ return };
        $('tr[class^="hoopla_page"]').hide();
        $(".hoopla_current_page").attr('data-page',new_page);
        $(".hoopla_current_page").data('page',new_page);
        $(".hoopla_current_page").text('Page ' + new_page + 'of ' + maxpage);
        if( $('.hoopla_page_'+new_page).length > 0 ) {
            $('.hoopla_page_'+new_page).show();
        } else {
            HooplaSearch( $("#hoopla_results").data('search') + "&offset=" + ( (new_page - 1) * 50 ), function(data){
                add_page_modal(data.titles, new_page);
                AddHooplaActions();
            });
        }
    });

    //Do the initial search and add links to Koha records
    $(document).ready(function(){
        //Add link to search results for records in Koha
        $(".results_summary.online_resources a[href*='www.hoopladigital.com']").each(function(){
            let content_url = $(this).attr('href');
            let content_id = "";
            if( content_url.match('&biblionumber=') ){
                content_id = content_url.substring( content_url.lastIndexOf('%2F') + 3, content_url.lastIndexOf('&'));
            } else {
                content_id = content_url.substring( content_url.lastIndexOf('/') + 1 );
            }
            content_id = unescape(content_id); //In the case of track links, the URL is encoded
            if( content_id.match('\\?') ){
                content_id = content_id.substring( 0, content_id.lastIndexOf('?') );
            }
            $(this).closest('.results_summary.online_resources').before('<span class="hoopla_result" data-content_id="'+content_id+'"><span>');
        });
        if( $("#results").length > 0 ){
            //Search hoopla using the querystring variable
            //Bug 25639 would help here
            let querystring_var = $("body").html().match(/var querystring = \"(.*)\"/);
            let querystring = "";
            if( querystring_var ){
                querystring = querystring_var[1].replace(/&quot;/g,'');
            }
            HooplaSearch( querystring, function(data){
                let maxpage = Math.floor(data.found/50) + 1;
                $("#numresults").append('<div id="hoopla_results" data-search="'+querystring+'" data-maxpage="'+maxpage+'"><a href="#">Found ' + data.found + ' results in Hoopla</a></div>');
                $(".hoopla_current_page").text("Page 1 of " + maxpage);
                add_page_modal(data.titles,1);
                AddHooplaActions();
            });
        } else if( $("#opac-detail").length > 0 ){
            AddHooplaActions();
        }

    });

    //Creates and populates the Hoopla Checkouts tab on patron summary on OPAC
    if( $("body#opac-user").length > 0 ) {
        $("#opac-user-views ul").append('<li class="nav-item" role="presentation"><a id="opac-user-hoopla-tab" class="nav-link" data-bs-toggle="tab" role="tab" aria-controls="opac-user-hoopla" aria-selected="false" href="#opac-user-hoopla_panel" data-bs-target="#opac-user-hoopla_panel">Hoopla Account</a></li>');
        $("#opac-user-views .tab-content").append('<div id="opac-user-hoopla_panel" class="tab-pane"><div id="content-hoopla"><p>Search the catalog to find and or checkout Hoopla items.</br>Click the links to visit the Hoopla site and login to download items or get the apps</p></div></div>');
        GetHooplaAccount(function(account){
            if( account.error ){
                $("#content-hoopla").append( account.error_text );
            } else if( typeof account.borrowsRemaining !== 'undefined' ){
                $("#content-hoopla").append('<h3>You have ' + account.borrowsRemaining + ' checkouts remaining of ' + account.borrowsAllowedPerMonth + ' allowed per month</h3>');
                if( account.currentlyBorrowed > 0 ){
                    $("#content-hoopla").append('<h4>Current checkouts</h4>');
                    $("#content-hoopla").append('<ul id="hoopla_checkouts"></ul>');
                    $.each( account.checkouts, function(index,checkout){
                        let date_due = new Date(checkout.due * 1000);
                        let checkout_item = '';
                        checkout_item += '<li>';
                        checkout_item += '<a target="_blank" href="'+ checkout.url + '">' + checkout.title 
                        + ' (' + checkout.kind + ')</a>';
                        checkout_item += '<span class="hoopla_result" data-content_id="'+checkout.contentId+'"></span>';
                        checkout_item += '</li>';
                        $("#hoopla_checkouts").append(checkout_item);
                    });
                    AddHooplaActions();
                }
            } else {
                $("#content-hoopla").html("<p id='hoopla_account_error'>There was a problem accessing your hoopla account, please see a staff member for assistance</p>");
            }
        });
    }

});

