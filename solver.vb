' -*- coding:utf-8 -*-

'
' Pentomino Puzzle Solver with Visual Basic
'

Imports System
Imports System.Linq
Imports System.Collections.Generic
Imports System.Text.RegularExpressions

Module Program

  Dim PIECE_DOC =
    "+-------+-------+-------+-------+-------+-------+." &
    "|       |   I   |  L    |  N    |       |       |." &
    "|   F F |   I   |  L    |  N    |  P P  | T T T |." &
    "| F F   |   I   |  L    |  N N  |  P P  |   T   |." &
    "|   F   |   I   |  L L  |    N  |  P    |   T   |." &
    "|       |   I   |       |       |       |       |." &
    "+-------+-------+-------+-------+-------+-------+." &
    "|       | V     | W     |   X   |    Y  | Z Z   |." &
    "| U   U | V     | W W   | X X X |  Y Y  |   Z   |." &
    "| U U U | V V V |   W W |   X   |    Y  |   Z Z |." &
    "|       |       |       |       |    Y  |       |." &
    "+-------+-------+-------+-------+-------+-------+."

' -------------------------------------------------------
  Dim debug_flg = False

  Structure Point
    Public X As Integer
    Public Y As Integer

    Sub New(x As Integer, y As Integer)
        Me.X = x
        Me.Y = y
    End Sub

    Function to_s() As String
      Return String.Format( "({0:D}, {1:D})", X, Y )
    End Function

  End Structure  'Point


  Class CFig
    Inherits List(Of Point )

    Sub New()
    End Sub

    Sub New( src As List(Of Point) )
      MyBase.New(src)
    End Sub

    Function to_s() As String
      Return String.join( ", ", Me.Select( Function( pt ) pt.to_s() ) )
    End Function
  End Class  'CFig


  Function PieceDef( id As Char ) As CFig
    Dim fig As New CFig()
    Dim xy As New Point( 0, 0 )
    For Each c in PIECE_DOC.toCharArray()
      If c = id Then  fig.Add( New Point( xy.X \ 2, xy.Y ) )
      xy.X += 1
      If c = "."c Then xy = New Point( 0, xy.Y + 1 )
    Next
    Return fig
  End FUnction

' -------------------------------------------------------

  Class CPiece
    Public Figs As List(Of CFig )
    Public Id   As Char
    Public Nxt  As CPiece

    Sub New( id_ As Char, org_fig As CFig, nxt_ As CPiece )
      Id   = id_
      Nxt  = nxt_
      Figs = New List(Of CFig )()

      For r_f = 0 to 7
        Dim fig = New CFig()

        For Each pt In org_fig    ' rotate & flip
          For i = 0 To  r_f mod 4                         ' rotate
             pt = New Point( -pt.Y, pt.X )
          Next

          If r_f >= 4 Then pt.X = -pt.X                   ' flip

          fig.Add( pt )
        Next  'pt

        ' sort
        fig.Sort( Function(a, b) If( a.Y = b.Y, a.X - b.X, a.Y - b.Y ) )

        ' normalize
        If fig.Count > 0 Then
          Dim o = fig.Item(0)
          fig = New CFig( fig.ConvertAll( _
                            Function(p) New Point(p.X-o.X, p.Y-o.Y) ))
        End If

        ' uniq
        If Not Figs.Exists( Function(lst) lst.SequenceEqual(fig) ) Then _
          Figs.Add(fig)

      Next  'r_f

      If debug_flg Then
        Console.WriteLine( id & ": ({0:D})", Figs.Count )
        For Each fig In Figs
          Console.WriteLine( "    [ {0} ]", fig.to_s() )
        Next
      End if

    End Sub

  End Class  'CPiece

' -------------------------------------------------------

  Class CBoard
    Public Cells(,) As Char
    Public ReadOnly Width  As Integer
    Public ReadOnly Height As Integer


    Sub New( w As Integer, h As Integer )
      Width  = w
      Height = h
      ReDim Cells( h - 1, w - 1 )

      For y = 0 To h - 1
        For x = 0 To w - 1
          Cells( y, x ) = " "c
        Next
      Next
      If w * h = 64 Then      ' 8x8 or 4x16
        Cells( h \ 2 - 1, w \ 2 - 1 ) = "@"c
        Cells( h \ 2 - 1, w \ 2     ) = "@"c
        Cells( h \ 2    , w \ 2 - 1 ) = "@"c
        Cells( h \ 2    , w \ 2     ) = "@"c
      End If

    End Sub


    Function At( x As Integer, y As Integer ) As Char
      If x >= 0 AndAlso x < Width AndAlso y >= 0 AndAlso y < Height Then
        Return Cells( y, x )
      Else
        Return "?"c
      End If
    End Function


    Function Check( x As Integer, y As Integer, fig As CFig ) As Boolean
      For Each pt In fig
        If At( x + pt.X, y + pt.Y ) <> " "c Then Return False
      Next
      Return True
    End Function


    Sub Place( x As Integer, y As Integer, fig As CFig, id As Char )
      For Each pt In fig
        Cells( y + pt.Y, x + pt.X ) = id
      Next
    End Sub


    Function FindSpace( x As Integer, y As Integer) As Point
      While Cells( y, x ) <> " "c
        x += 1
        If x < Width Then Continue While
        x = 0
        y += 1
      End While
      Return New Point( x, y )
    End Function


    '         2
    ' (-1,-1) | (0,-1)
    '   ---4--+--1----
    ' (-1, 0) | (0, 0)
    '         8
    '          0      3     5    6    7     9    10   11   12   13   14   15
    Const e1="    ,,,+---,,----,+   ,+---,,+---,|   ,+---,+   ,+---,+   ,+---"
    Const e2="    ,,,    ,,    ,    ,    ,,|   ,|   ,|   ,|   ,|   ,|   ,|   "
    Shared ELEMS()() As String = { e1.Split(","c), e2.Split(","c) }

    Function Render() As String
      Dim lines = ""
      For y = 0 To Height
        For d = 0 to 1
          Dim line = ""
          For x = 0 To Width
            Dim code = If( At( x+0, y+0 ) <> At( x+0, y-1 ), 1, 0 ) +
                       If( At( x+0, y-1 ) <> At( x-1, y-1 ), 2, 0 ) +
                       If( At( x-1, y-1 ) <> At( x-1, y+0 ), 4, 0 ) +
                       If( At( x-1, y+0 ) <> At( x+0, y+0 ), 8, 0 )
            line += ELEMS(d)(code)
          Next
          lines += line & vbCrLf
        Next
      Next
      Return lines
    End Function

  End Class  'CBoard

' -------------------------------------------------------

  Class CSolver
    Public Unused As CPiece
    Public board  As CBoard
    Public Solutions = 0
    Public Pieces As New Dictionary(Of Char, CPiece )

    Sub New( w As Integer, h As Integer )
      board = New CBoard( w, h )

      Dim pc As CPiece = Nothing
      For Each id As Char In "FILNPTUVWXYZ".Reverse()
        pc = New CPiece( id, PieceDef( id ), pc )
      Next
      Unused = New CPiece( "!", New CFig(), pc )       ' dummy piece
      ' limit the symetries of "F"
      pc.Figs = pc.Figs.GetRange( 0, If( w = h, 1, 2 ) )
    End Sub


    Sub Solve( x As Integer, y As Integer )
      If Unused.Nxt IsNot Nothing
        Dim xy = board.FindSpace( x, y )
        x = xy.X
        y = xy.Y
        Dim prev = Unused
        While True
          Dim pc = prev.Nxt
          If pc Is Nothing Then Exit While
          prev.Nxt = pc.Nxt
          For Each fig In pc.Figs
            If board.Check( x, y, fig ) Then
              board.Place( x, y, fig, pc.Id )
              Solve( x, y )                    ' call reucrsively
              board.Place( x, y, fig, " "c )
            End If
          Next
          prev.Nxt = pc
          prev     = pc
        End While
      Else
        Solutions += 1
        Dim cursup = If(Solutions > 1, Chr(27)&"["&(board.Height*2+3) &"A", "")
        Console.WriteLine( "{0}{1}{2}", cursup, board.Render, Solutions )
      End If

    End Sub

  End Class  'CSolver

' -------------------------------------------------------

  Public Sub Main( args As String())
    Dim width  = 6
    Dim height = 10
    For Each arg In args
      If arg = "--debug"  Then debug_flg = True
      Dim m = Regex.Match( arg, "^(\d+)\D(\d+)$" )
      If m.Success Then
        Dim w = Integer.Parse( m.Groups(1).Value )
        Dim h = Integer.Parse( m.Groups(2).Value )
        If w >= 3 AndAlso h >= 3 AndAlso ( w * h = 60 OrElse w * h = 64 ) Then
           width  = w
           height = h
        End If
      End If
    Next

    Dim solver = New CSolver( width, height )
    solver.Solve( 0, 0 )
  End Sub

End Module
