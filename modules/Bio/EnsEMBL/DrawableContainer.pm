package Bio::EnsEMBL::DrawableContainer;
use lib "../../../../bioperl-live";
use Bio::Root::RootI;
use strict;
use Bio::EnsEMBL::Renderer::imagemap;
use Bio::EnsEMBL::Renderer::gif;
use Bio::EnsEMBL::Renderer::wmf;
use vars qw(@ISA);

use constant GLYPHSET_PATH => '/mysql/ensembl/www/server/ensembl-draw/modules';

@ISA = qw(Bio::Root::RootI);

=head1 NAME

Bio::EnsEMBL::DrawableContainer - top level container for ensembl-draw drawing code.

=head1 SYNOPSIS

Bio::EnsEMBL::DrawableContainer is a container class for any number of GlyphSets.

=cut

@ISA = qw(Exporter);

=head1 METHODS

=head2 new - Class constructor.

my $gss = new Bio::EnsEMBL::DrawableContainer($display, $Container, $ConfigObject);

	$display       - contigviewtop|contigviewbottom|
	$Container     - vc|other_container_obj on which the image will be built
	$ConfigObject  - WebUserConfig object

=cut

sub new {
    my ($class, $display, $Container, $Config, $highlights) = @_;

    if(!defined $display) {
	print STDERR qq(Bio::EnsEMBL::DrawableContainer::new No display type defined\n);
	return;
    }

    if($display !~ /transview|contigviewbottom/) {
	print STDERR qq(Bio::EnsEMBL::DrawableContainer::new Unknown display type $display\n);
	return;
    }

    if(!defined $Container) {
	print STDERR qq(Bio::EnsEMBL::DrawableContainer::new No vc defined\n);
	return;
    }

    if(!defined $Config) {
	print STDERR qq(Bio::EnsEMBL::DrawableContainer::new No Config object defined\n);
	return;
    }

    my $self = {
	'vc'         => $Container,
	'display'    => $display,
	'glyphsets'  => [],
	'config'     => $Config,
    };

    #########
    # loop over all the glyphsets the user wants:
    #

    for my $row ($Config->subsections($self->{'display'})) {
	#########
	# skip this row if user has it turned off
	#
	next if ($Config->get($self->{'display'}, $row, 'on') eq "off");

	#########
	# create a new glyphset for this row
	#
	my $classname = qq(Bio::EnsEMBL::GlyphSet::$row);
	my $classpath = &GLYPHSET_PATH . qq(/Bio/EnsEMBL/GlyphSet/${row}.pm);

	#########
	# require & import the package
	#
	eval {
	    require($classpath);
	};
	if($@) {
	    print STDERR qq(DrawableContainer::new failed to require $classname\n);
	    next;
	}

	$classname->import();

	#########
	# generate a set for both strands
	#
	my $ustrand = $Config->get($self->{'display'}, $row, 'str');

	if($ustrand eq "b" || $ustrand eq "f") {
	    my $GlyphSet = new $classname($Container, $Config, qq(|$highlights|), 1);
	    push @{$self->{'glyphsets'}}, $GlyphSet;
	}

	if($ustrand eq "b" || $ustrand eq "r") {
	    my $GlyphSet = new $classname($Container, $Config, qq(|$highlights|), -1);
	    push @{$self->{'glyphsets'}}, $GlyphSet;
	}
    }

    bless($self, $class);
    return $self;
}

=head2 render - renders object data into an image

my $imagestring = $gss->render($type);

	$type        - imagemap|gif|png|ps|pdf|tiff|wmf|fla

=cut

#########
# render does clever drawing things
#
sub render {
    my ($this, $type) = @_;

    #########
    # query boundary conditions of glyphsets?
    # set up canvas?
    # DO GLOBBING & BUMPING!!!
    #

    my ($width, $height) = $this->config()->dimensions();

    my ($minx, $maxx, $miny, $maxy);

    for my $gs ($this->glyphsets()) {
	next if($gs->maxx() == 0 || $gs->maxy() == 0);
	$minx = $gs->minx() if($gs->minx() < $minx || !defined($minx));
	$maxx = $gs->maxx() if($gs->maxx() > $maxx || !defined($maxx));
	$miny = $gs->miny() if($gs->miny() < $miny || !defined($miny));
	$maxy = $gs->maxy() if($gs->maxy() > $maxy || !defined($maxy));
    }

    my $scalex = $width / ($maxx - $minx);
    my $scaley = $height / ($maxy - $miny);

print STDERR qq(Using y scaling factor $scaley and x scaling factor $scalex\n);

    my $transform_ref = {
	'translatex' => 0,
	'translatey' => 0,
	'scalex'     => $scalex,
	'scaley'     => $scaley,
#	'rotation'   => 90,
    };

    #########
    # initialise canvasses for specific image types
    #
    my $canvas;
    if($type eq "gif") {
	$canvas = new GD::Image($width, $height);
	$canvas->colorAllocate(255,255,255);

    } elsif($type eq "wmf") {
	$canvas = new WMF($width, $height);
	$canvas->colorAllocate(255,255,255);

    }

    #########
    # build the type of render object we want
    #
    my $renderer_type = qq(Bio::EnsEMBL::Renderer::$type);

    #########
    # big, shiny, rendering 'GO' button
    #
    my $renderer = $renderer_type->new($this->{'glyphsets'}, $transform_ref, $canvas);

    return $renderer->canvas();
}

sub config {
    my ($this, $Config) = @_;
    $this->{'config'} = $Config if(defined $Config);
    return $this->{'config'};
}

sub glyphsets {
    my ($this) = @_;
    return @{$this->{'glyphsets'}};
}

1;

=head1 RELATED MODULES

See also: Bio::EnsEMBL::GlyphSet Bio::EnsEMBL::Glyph WebUserConfig

=head1 AUTHOR - Roger Pettett

Email - rmp@sanger.ac.uk

=cut
