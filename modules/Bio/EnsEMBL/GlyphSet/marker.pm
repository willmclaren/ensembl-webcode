package Bio::EnsEMBL::GlyphSet::marker;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

sub my_label { return "Markers"; }

sub features {
    my ($self) = @_;
    return [ $self->{'container'}->get_landmark_MarkerFeatures() ];
}

sub href {
    my ($self, $f ) = @_;
    return "/$ENV{'ENSEMBL_SPECIES'}/markerview?marker=".$f->id;
}
sub zmenu {
    my ($self, $f ) = @_;
    return { 
        'caption' => $f->id,
	    'Marker info' => $self->href($f)
    };
}
1;
