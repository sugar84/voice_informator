#!/usr/bin/perl
use warnings;
use strict;
use LWP::UserAgent;
use XML::Simple;
#use Data::Dumper;
#use Data::Dump qw(dump);
use Net::Ping;
use utf8;

###############################################################################
### CONFIGURATION
###############################################################################
my ($min_t, $max_t, $min_t_mor, $max_t_mor, $time_section);
my $subj = "температура на улице ";
# variable for checking talk or not forecast on the morning
my $talk_mor = "1";

my $url = "http://informer.gismeteo.ru/xml/34731_1.xml";
my ($xml_data, @phrases_to_say);
###############################################################################

### Main section

binmode STDOUT, ":utf8";

my $xml = get_data($url);
my $data_ref = ext_data_from_xml($xml);

#print dump($data_ref);
if ($talk_mor) {
    $time_section = get_time_mor($data_ref);
}
my $temps_ref = ext_temp($data_ref, $time_section);
my $time = get_time_mor($data_ref);
my $hitime = hi_time($time);

my $units_now = word_form($temps_ref->{'current_max'});
my $units_mor = word_form($temps_ref->{'next_max'});

push @phrases_to_say, join " ", $hitime,  $subj, $temps_ref->{'current_min'},
        $temps_ref->{'current_max'}, $units_now;

# talk forecast for the morning 
if ($talk_mor) {
    push @phrases_to_say, join " ", "Температура на утро ", 
            $temps_ref->{'next_min'}, $temps_ref->{'next_max'}, $units_mor;
}

# 
#foreach my $aa (@phrases_to_say  ) {
#    print $aa, "\n";
#}
say_info( @phrases_to_say );

# print Dumper($gl_data);

### Subs

sub get_xml {
    my ($forecast_url) = @_;
    
    my $ua = LWP::UserAgent->new;
    $ua->agent("Get the weather");
    
    # Create a request
    my $req = HTTP::Request->new(POST => "$forecast_url");
    $req->content_type('application/x-www-form-urlencoded');
    $req->content('query=libwww-perl&mode=dist');
    
    # Pass request to the user agent and get a response back
    my $res = $ua->request($req);
    # Check the outcome of the response
    if ($res->is_success) {
        return $res->content;
    } else {
        return 0;
    }
}

sub get_data {
    my ($forecast_url) = @_;
    
    my $xml_data;
    LEECH:
    for my $i (1..3) {
        $xml_data = get_xml($forecast_url);
        last LEECH if ($xml_data);
    }    
    if (!$xml_data) {
        my $test = check_internet();
        return $test; 
    }
    return $xml_data;
}

# extract data from xml
sub ext_data_from_xml {
    my ($xml) = @_;
    
    my $fulldata_ref = XMLin($xml);
    
    # left here information related only to the forecast
    my $result_arr_ref = $fulldata_ref->{'REPORT'}->{'TOWN'}->{'FORECAST'};
    return $result_arr_ref;
}

sub ext_temp {
    my ($all_data_ref, $time) = @_;
    my %temps = ();
    
#    print dump($all_data_ref);
    # extract temperature for the _current_ time
    $temps{'current_min'} = $all_data_ref->[0]->{TEMPERATURE}->{min};
    $temps{'current_max'} = $all_data_ref->[0]->{TEMPERATURE}->{max};
    
    # extract temperature for the _future_ time
    if ($talk_mor) {
        $temps{'next_min'} = $all_data_ref->[$time]->{TEMPERATURE}->{min};
        $temps{'next_max'} = $all_data_ref->[$time]->{TEMPERATURE}->{max};
    }
    return \%temps;
}

sub check_google {
    my $p = Net::Ping->new("tcp");
    
    $p->port_number("80");
    my $host1 = 'www.google.ru';
    my $host2 = '4.2.2.2'; 
    my $res_of_ping = "";
    # number of pings
    my $num = 3;
    
    foreach my $i (1..3) {    
        if ($p->ping($host1)) {
            $res_of_ping = "reachable";
            last;
        }
        elsif ($p->ping($host2)) {
            $res_of_ping = "dns is unreachable";
        }
    }
    $p->close;
    return $res_of_ping;
}

# процедура проверки, если все не ок то пинг три раза гугл, если  пинг =0, 
# то die (интернет недоступен)
sub check_internet {
    my $res_of_sub = check_google;
    
    if ($res_of_sub) {
        if ($res_of_sub =~ /^reach/) {
            return "интернет доступен, но сайт погоды не доступен\n";
        } 
        elsif ($res_of_sub =~ /^dns/) {
            return "интернет доступен, но есть проблема с сервером имен\n";
        }
    } else {
        return "интернет недоступен\n";
    }
}

sub compose_time {
    my ($hour, $min) = (localtime)[2,1];
    my ($hour_unit, $min_unit);
    
    SWITCH: {
#        if ($hour < 6 or $hour == 23)   { $phrase = "Доброй ночи"; last SWITCH; }
#        if ($hour >= 6  and $hour < 12) { $phrase = "Доброе утро"; last SWITCH; }
#        if ($hour >= 12 and $hour < 18) { $phrase = "Добрый день"; last SWITCH; }
#        if ($hour >= 18)                { $phrase = "Добрый вечер"; last SWITCH; }
#        заменить все
    }
}

sub hi_time {
    my $hour = (localtime)[2];
    my $phrase;
    
    SWITCH: {
        if ($hour < 6 or $hour == 23)   { $phrase = "Доброй ночи"; last SWITCH; }
        if ($hour >= 6  and $hour < 12) { $phrase = "Доброе утро"; last SWITCH; }
        if ($hour >= 12 and $hour < 18) { $phrase = "Добрый день"; last SWITCH; }
        if ($hour >= 18)                { $phrase = "Добрый вечер"; last SWITCH; }
        $phrase = "Доброго времени суток";
    }
    return $phrase;
}

sub word_form {
    my ($last_digit) = @_;

#    print $last_digit, "AAAAAAAAAAAAAA!!!!!!!!!!!!!!!!!!!\n";
    if ($last_digit  >= 20) {
        $last_digit = chop $last_digit
    }
    my $word;
    SWITCH: {
        if ($last_digit == 1) { $word = "градус"; last SWITCH }
        if ($last_digit >= 2 and $last_digit <= 4) { $word = "градуса"; last SWITCH }
        if ($last_digit >=5 or $last_digit == 0) { $word = "градусов"; last SWITCH }
    }
    return $word;
}

sub construct_time {
    my ($minute, $hour) = (localtime)[1,2];
    
    my $last_hour = chop $hour if $hour >= 20;
    my $last_min  = chop $minute if $minute >= 20;
    my ($hour_unit, $min_unint);

    SWITCH1: {
        if ($last_hour == 1) { $hour_unit = "час"; last SWITCH1 }
        if ($last_hour >= 2 and $last_hour <= 4) { $hour_unit = "часа"; last SWITCH1 }
        if ($last_hour >=5 or  $last_hour == 0) { $hour_unit = "часов"; last SWITCH1 }
    }

    SWITCH2: {
        if ($last_min == 1) { $min_unit = "минута"; last SWITCH2 }
        if ($last_min >= 2 and $last_min <= 4) { $min_unit = "минуты"; last SWITCH2 }
        if ($last_min >=5 or  $last_min == 0) { $min_unit = "минут"; last SWITCH2 }
    }
    return ($minute, $min_unit, $hour, $hour_unit);
}

sub get_time_mor {
    my ($data) = @_;

    my $length = scalar @{$data} - 1;
#    my $length = 4;
    foreach my $i (0..$length) {
        return $i if ($data->[$i]->{hour} == 9);
    }
}

# need to get sub that determines current time scheme of the weather
# provider (eg. gismeteo)#
sub deter_time{

}

sub take_opts {
# my 
}

sub info_to_speaker {
    my ($speaker, @to_say_it) = @_;

    my $festival = "/usr/bin/festival";
    my $voiceman = "/usr/bin/voiceman";
    
    if ($speaker eq "voiceman") {
        foreach my $string (@to_say_it) {
            utf8::encode($string);
            # this is for voiceman client, that see on the environment variable $LANG 
            # and convert_to_english( "принимает решение" )
            $ENV{"LANG"} = "ru_RU.UTF-8";
            qx( echo $string | $voiceman );
        }
    }
    elsif ($speaker eq "festival") {
        foreach my $string (@to_say_it) {
            utf8::encode($string);
            qx( echo $string | $festival --tts --language russian );
        }
    }
    return;
}

#sub player_manage {
#    my ($player, $time) = @_;
#}

sub say_info {
    my @phrases_to_say = @_;

    my $prog_speaker = "festival";
    my $amarok_dbus_status = qx( /usr/bin/dbus-send --print-reply --dest=org.kde.amarok /Player org.freedesktop.MediaPlayer.GetStatus );
    my ($play_status) =  $amarok_dbus_status =~ /int32 (\d)/;
    if (defined $play_status and $play_status == 0) {
        system '/usr/bin/dbus-send --type=method_call --dest=org.kde.amarok ' . 
                '/Player org.freedesktop.MediaPlayer.Pause';
        info_to_speaker( $prog_speaker, @phrases_to_say );
        sleep 10;
        system '/usr/bin/dbus-send --type=method_call --dest=org.kde.amarok ' .
                '/Player org.freedesktop.MediaPlayer.Play';
    } else {
        info_to_speaker( $prog_speaker, @phrases_to_say );
    }
    return;
}
