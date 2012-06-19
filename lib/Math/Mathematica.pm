package Math::Mathematica;

=head1 NAME

Math::Mathematica - A Simple PTY connection to Wolfram's Mathematica

=head1 SYNOPSIS

 use Math::Mathematica;
 my $math = Math::Mathematica->new;
 my $result = $math->evaluate('Integrate[Sin[x],{x,0,Pi}]'); # 2

=head1 DESCRIPTION

Although there are more clever mechanisms to interact with Wolfram's Mathematica (namely MathLink) they are very hard to write. L<Math::Mathematica> simply starts a PTY, runs the command line C<math> program, and manages input/output via string transport. While a MathLink client for Perl would be ideal, this module gets the job done.

=cut

use strict;
use warnings;

our $VERSION = '0.001';
$VERSION = eval $VERSION;

use Carp;
use IO::Pty::Easy;

my $re_new_prompt = qr/In\[\d+\]:= /;
my $re_result = qr/Out\[\d+\]= (.*?)$re_new_prompt/ms;

=head1 METHODS

=cut

sub new {
  my $class = shift;
  my %opts = ref $_[0] ? %{ shift() } : @_;

  $opts{log}     = 1      unless defined $opts{log};
  $opts{command} = 'math' unless defined $opts{command};

  my $self = {
    pty        => IO::Pty::Easy->new(),
    log        => $opts{log} ? '' : undef,
    warn_after => $opts{warn_after} || 10,
    command    => $opts{command},
  };

  bless $self, $class;

  $self->pty->spawn($self->{command}) 
    or croak "Could not connect to Mathematica";
  $self->_wait_for_prompt;

  return $self;
}

sub evaluate {
  my ($self, $command) = @_;
  my $pty = $self->pty;
  $command .= "\n";

  $self->log($command);
  $pty->write($command, 0) or croak "No data sent";

  my $output = $self->_wait_for_prompt;
  my $return = $1 if $output =~ $re_result;
  $return =~ s/[\n\s]*$//;
  
  return $return;
}

sub _wait_for_prompt {
  my $self = shift;
  my $pty = $self->pty;

  my $null_loops = 0;
  my $output = '';
  while ($pty->is_active) {
    my $read = $pty->read(1);
    if (defined $read) {
      $output .= $read;
      $null_loops = 0;
    } else {
      carp "Response from Mathematica is taking longer than expected" 
        if ++$null_loops >= $self->{warn_after};
    }
    last if $output =~ $re_new_prompt; 
  }

  $self->log($output);
  return $output;
}

sub DESTROY { shift->pty->close }

sub pty {shift->{pty}}

sub log {
  my $self = shift;
  if ( @_ and defined $self->{log} ) {
    $self->{log} .= $_ for @_;
  }
  return $self->{log};
}
