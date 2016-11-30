#!/usr/bin/perl

use strict;
use warnings;
use DBI qw(:sql_types);
use YAML::Tiny qw[Dump];

binmode(STDOUT, ":utf8");

my $dbfile = shift // 'dnd.sqlite';
my $dbh = DBI->connect("dbi:SQLite:dbname=$dbfile","","")
  or die('Could not connect to database');

my $sql = <<'EOS';
SELECT
dnd_spell.name, dnd_spellschool.name,
dnd_spell.verbal_component, dnd_spell.somatic_component,
dnd_spell.material_component, dnd_spell.arcane_focus_component,
dnd_spell.divine_focus_component, dnd_spell.xp_component,
dnd_spell.casting_time, dnd_spell.range, dnd_spell.target,
dnd_spell.effect, dnd_spell.area, dnd_spell.duration,
dnd_spell.saving_throw, dnd_spell.spell_resistance,
dnd_spell.description, dnd_spell.id
FROM dnd_spell, dnd_spellschool
WHERE dnd_spell.rulebook_id = 6 AND
dnd_spellschool.id = dnd_spell.school_id;
EOS

# Fetch all spells from PHB
my $sth = $dbh->prepare($sql);
my $row;

$sth->execute() or die('Could not run query');

sub stripshit {
    my $description = shift;

    return unless $description;
    return if $description eq '';

    ($description) =~ s/([^\s]+)\:([^\s]+)/$1/ig;

    return $description;
}

sub str2bool {
    my $str = shift;
    return 0 unless $str;
    return 1 if "$str" eq 'Yes' or "$str" eq '1';
    return 0;
}

my @spells = ();

while ($row = $sth->fetch()) {
    my $obj = {};

    $obj->{'name'} = $row->[0];
    $obj->{'school'} = $row->[1];

    my $components = {};

    $components->{'verbal'} = $row->[2];
    $components->{'somatic'} = $row->[3];
    $components->{'material'} = $row->[4];
    $components->{'arcanefocus'} = $row->[5];
    $components->{'divinefocus'} = $row->[6];
    $components->{'xp'} = $row->[7];
    $obj->{'components'} = $components;

    $obj->{'castingtime'} = $row->[8];
    $obj->{'range'} = $row->[9];
    $obj->{'target'} = $row->[10];
    $obj->{'effect'} =  $row->[11];
    $obj->{'area'} = $row->[12];
    $obj->{'duration'} = $row->[13];
    $obj->{'savingthrow'} = $row->[14];
    $obj->{'spellresistance'} = str2bool($row->[15]);

    $obj->{'description'} = stripshit($row->[16]);

    # Now build spell levels for classes
    my $lvlsql = <<"EOS";
SELECT dnd_characterclass.name,
dnd_spellclasslevel.level,
dnd_spellclasslevel.extra
FROM dnd_spellclasslevel, dnd_characterclass, dnd_spell
WHERE dnd_spell.id = dnd_spellclasslevel.spell_id AND
dnd_characterclass.id = dnd_spellclasslevel.character_class_id AND
dnd_spell.id = ?
EOS

    my $lvlsth = $dbh->prepare($lvlsql);
    $lvlsth->bind_param(1, $row->[17], SQL_INTEGER);
    $lvlsth->execute();
    my $lr;
    my $levels = {};

    while ($lr = $lvlsth->fetch()) {
        $levels->{$lr->[0]} = $lr->[1];
    }

    $obj->{'levels'} = $levels;

    # And now domains
    my $domainsql = <<"EOS";
SELECT dnd_domain.name,
dnd_spelldomainlevel.level,
dnd_spelldomainlevel.extra
FROM dnd_spelldomainlevel, dnd_domain, dnd_spell
WHERE dnd_spell.id = dnd_spelldomainlevel.spell_id AND
dnd_domain.id = dnd_spelldomainlevel.domain_id AND
dnd_spell.id = ?
EOS

    my $domainsth = $dbh->prepare($domainsql);
    $domainsth->bind_param(1, $row->[17], SQL_INTEGER);
    $domainsth->execute();
    my $dmn;
    my $domains = {};

    while ($dmn = $domainsth->fetch()) {
        $domains->{$dmn->[0]} = $dmn->[1];
    }

    $obj->{'domains'} = $domains;

    push(@spells, $obj);
}

print(Dump(\@spells));

$dbh->disconnect();
