package Bio::EnsEMBL::GlyphSet::repeat_dr_lite;
use strict;
use vars qw(@ISA);
@ISA = qw( Bio::EnsEMBL::GlyphSet::repeat_lite );
sub my_label { return "Repeats (D.Rerio)"; }

sub features {
    my $self = shift;
    return $self->{'container'}->get_all_RepeatFeatures_lite( 'Dr', $self->glob_bp() );
}
