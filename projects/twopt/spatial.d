module spatial;

import std.algorithm, std.math;

// The three directions -- typesafe 
enum Direction {x,y,z};


// Template constraints for 3D points
private template isPoint(P) {
	const isPoint = __traits(compiles, 
		(P p) {
			p.x = 0;
			p.y = 0;
			p.z = 0;
			});
}

unittest {
	struct WPoint {
		float x,y,z,w;
	}
	struct Point {
		float x,y,z;
	}
	struct NotAPoint {
		float x,y;
	}
	assert(isPoint!Point,"Point should be a point");
	assert(isPoint!WPoint, "WPoint should be a point");
	assert(!isPoint!NotAPoint, "NotAPoint should not be a point");
}

// Sort the array along the chosen dimension
void splitOn(P) (P[] points, Direction dir) 
	if (isPoint!P) 
{
	auto nel = points.length;
	if (nel==0) throw new Exception("Cannot split a zero element array");	
	auto mid = (nel-1)/2;
	final switch(dir) {
		case Direction.x : 
			topN!("a.x < b.x")(points, mid);
			break;
		case Direction.y :
			topN!("a.y < b.y")(points, mid);
			break;
		case Direction.z :
			topN!("a.z < b.z")(points, mid);
			break;
	}
}

unittest {
	struct Point {
		float x,y,z;
	}
	auto p1 = [Point(1,2,3),Point(3,1,2),Point(2,3,1)];
	splitOn(p1,Direction.x);
	assert(p1[1]==Point(2,3,1));
	splitOn(p1,Direction.y);
	assert(p1[1]==Point(1,2,3));
	splitOn(p1,Direction.z);
	assert(p1[1]==Point(3,1,2));
}



// The bounding box for a set of particles. We store the center of the box
// and the size of the box in each dimension. We also compute and store the
// largest of these and the direction that corresponds to.
struct BoundingBox {
	double xcen, ycen, zcen, dx, dy, dz, maxl;
	Direction maxdir;

	// Get the bounding box for the array
	this(P) (P[] points) 
		if (isPoint!P)
	{
		double xmin,ymin,zmin,xmax,ymax,zmax;
		xmin = points[0].x; ymin = points[0].y; zmin = points[0].z;
		xmax = points[0].x; ymax = points[0].y; zmax = points[0].z;
		foreach (p; points) {
			if (p.x < xmin) xmin=p.x;
			if (p.y < ymin) ymin=p.y;
			if (p.z < zmin) zmin=p.z;
			if (p.x > xmax) xmax=p.x;
			if (p.y > ymax) ymax=p.y;
			if (p.z > zmax) zmax=p.z;
		}
		xcen = (xmin+xmax)/2;
		ycen = (ymin+ymax)/2;
		zcen = (zmin+zmax)/2;
		dx = xmax - xmin;
		dy = ymax - ymin;
		dz = zmax - zmin;
		auto maxpos = 3 - minPos!("a>b")([dx,dy,dz]).length;
		switch (maxpos) {
			case 0 : 
				maxdir = Direction.x;
				maxl = dx;
				break;
			case 1 : 
				maxdir = Direction.y;
				maxl = dy;
				break;
			case 2 : 
				maxdir = Direction.z;
				maxl = dz;
				break;
			default : break;
		}
	}

}

unittest {
	struct Point {
		float x,y,z;
	}
	auto p1 = [Point(0,0,3), Point(1,0,3), Point(-1,0,0)];
	auto box=BoundingBox(p1);
	assert(approxEqual(box.xcen, 0));
	assert(approxEqual(box.ycen, 0));
	assert(approxEqual(box.zcen, 1.5));
	assert(approxEqual(box.dx,2));
	assert(approxEqual(box.dy,0));
	assert(approxEqual(box.dz,3));
	assert(box.maxdir == Direction.z);
}




class KDNode(P) if (isPoint!P) {
	uint id;
	P[] arr;
	BoundingBox box;
	KDNode left, right;

	this(P)(P[] points, double minLength=0, uint minPart=1, uint id=0, bool buildTree=true) 
	{
		auto nel = points.length;
		if (nel==0) throw new Exception("Cannot build around zero element array");
		if (minPart < 1) throw new Exception("minPart cannot be less than 1");	
		arr = points;
		box = BoundingBox(points);
		id = id;

		// Determines when to return
		if (!buildTree) return;
		if (nel < minPart) return;
		if (box.maxl < minLength) return;

		// Subdivide the tree
		splitOn(arr, box.maxdir);
		auto pos = nel/2;
		left = new KDNode(arr[0..pos], minLength, minPart, 2*id+1, true);
		right = new KDNode(arr[pos..$], minLength, minPart, 2*id+2, true);
	}

	@property bool isLeaf() {
		return (left is null) && (right is null);
	}
}



unittest {
	struct Point {
		float x,y,z;
	}
	auto p1 = [Point(0,0,0), Point(1,0,0), Point(-1,0,0), Point(-2,0,0)];
	assert(!isSorted!("a.x < b.x")(p1));
	auto root = new KDNode!Point(p1,2);	
	// Ensure that the array was not copied
	assert(root.arr is p1);
	assert(root.box.maxdir == Direction.x);
	assert(!root.isLeaf);
	assert(root.left.isLeaf);
	assert(root.right.isLeaf);
	assert(root.left.arr.length == 2);
	assert(root.right.arr.length == 2);
	assert(isSorted!("a.x < b.x")(p1));
}







