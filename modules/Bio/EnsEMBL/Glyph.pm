package Bio::EnsEMBL::Glyph;
use strict;
use lib "../../../../modules";
use ColourMap;
use Exporter;
use vars qw(@ISA $AUTOLOAD);
@ISA = qw(Exporter);

#########
# constructor
# _methods is a hash of valid methods you can call on this object
#
sub new {
    my ($class, $params_ref) = @_;
    my $self = {
	'background' => 'transparent',
	'composite'  => undef,           # arrayref for Glyph::Composite to store other glyphs in
	'points'     => [],		 # listref for Glyph::Poly to store x,y paired points
    };
    bless($self, $class);

    #########
    # initialise all fields except type
    #
    for my $field (qw(x y width height text colour bordercolour font onmouseover onmouseout zmenu href pen brush background id points absolutex absolutey)) {
	$self->{$field} = $$params_ref{$field} if(defined $$params_ref{$field});
    }

    return $self;
}

#########
# read-write methods
#
sub AUTOLOAD {
    my ($this, $val) = @_;
    my $field = $AUTOLOAD;
    $field =~ s/.*:://;

    $this->{$field} = $val if(defined $val);
    return $this->{$field};
}

#########
# apply a transformation.
# pass in a hashref containing keys
#  - translatex
#  - translatey
#  - scalex
#  - scaley
#
sub transform {
    my ($this, $transform_ref) = @_;

    my $scalex     = $$transform_ref{'scalex'}     || 1;
    my $scaley     = $$transform_ref{'scaley'}     || 1;
    my $translatex = $$transform_ref{'translatex'} || 0;
    my $translatey = $$transform_ref{'translatey'} || 0;
    my $rotation   = $$transform_ref{'rotation'}   || 0;
    my $clipx      = $$transform_ref{'clipx'}      || 0;
    my $clipy      = $$transform_ref{'clipy'}      || 0;
    my $clipwidth  = $$transform_ref{'clipwidth'}  || 0;
    my $clipheight = $$transform_ref{'clipheight'} || 0;

    #########
    # override transformation if we've set x/y to be absolute (pixel) coords
    #
    if(defined $this->absolutex()) {
	$scalex     = 1;
	$translatex = 0;
    }

    if(defined $this->absolutey()) {
	$scaley     = 1;
	$translatey = 0;
    }

    #########
    # apply scale
    #
    $this->pixelx      (int($this->x()      * $scalex));
    $this->pixely      (int($this->y()      * $scaley));
    $this->pixelwidth  (int($this->width()  * $scalex));
    $this->pixelheight (int($this->height() * $scaley));

    #########
    # apply translation
    #
    $this->pixelx($this->pixelx() + $translatex);
    $this->pixely($this->pixely() + $translatey);

    #########
    # apply mirror along x=y, flip along x=0 & translate x+=width
    # this is nasty rotation without the even nastier matrix manipulation
    #
    if($rotation == 90) {
	#########
	# mirror in x=y
	#
	my $t1 = $this->pixelx();
	$this->pixelx($this->pixely());
	$this->pixely($t1);

	my $t2 = $this->pixelwidth();
	$this->pixelwidth($this->pixelheight());
	$this->pixelheight($t2);

	#########
	# flip along x=0
	#
	$this->pixelx(-$this->pixelx());

	#########
	# translate x+=width
	#
	$this->pixelx($this->pixelx() + $clipwidth);
    }
}
